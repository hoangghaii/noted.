#!/usr/bin/env python3
"""Pinned, local conversion attempt for the Phase 01 E5 candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
from pathlib import Path


HERE = Path(__file__).resolve().parent
LOCK = json.loads((HERE / "model.lock.json").read_text())
FILES = [
    "README.md", "config.json", "model.safetensors", "sentencepiece.bpe.model",
    "special_tokens_map.json", "tokenizer.json", "tokenizer_config.json",
]
SAMPLES = [
    ("vi-coffee", "query", "quán cà phê yên tĩnh để đọc sách"),
    ("vi-job", "passage", "Tìm việc lập trình Java ở Hà Nội"),
    ("vi-no-diacritics", "query", "quan ca phe gan nha"),
    ("en-mixed", "passage", "Coffee menu and software engineering notes"),
]
MAX_TOKENS = 128


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_files(source: Path) -> dict[str, str]:
    hashes = {}
    for name in FILES:
        path = source / name
        if not path.is_file():
            raise FileNotFoundError(f"Missing pinned upstream file: {path}")
        actual = sha256(path)
        expected = LOCK["files_sha256"].get(name)
        if expected and actual != expected:
            raise ValueError(f"SHA-256 mismatch for {name}: {actual} != {expected}")
        hashes[name] = actual
    return hashes


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--offline", action="store_true", help="Use existing Hugging Face cache only")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    # Imports are deliberately after argument parsing: --help works without heavy dependencies.
    import coremltools as ct
    import coremltools.optimize as cto
    import numpy as np
    import torch
    import transformers
    from huggingface_hub import snapshot_download
    from transformers import AutoModel, AutoTokenizer

    source = Path(snapshot_download(
        repo_id=LOCK["repository"], revision=LOCK["revision"],
        allow_patterns=FILES, local_files_only=args.offline,
        cache_dir=str(output / "hf-cache"),
    ))
    hashes = verify_files(source)
    for name in ("README.md", "tokenizer.json", "tokenizer_config.json", "special_tokens_map.json",
                 "sentencepiece.bpe.model"):
        shutil.copy2(source / name, output / name)

    tokenizer = AutoTokenizer.from_pretrained(source, use_fast=True, local_files_only=True,
                                              trust_remote_code=False)
    model = AutoModel.from_pretrained(source, local_files_only=True, use_safetensors=True,
                                     trust_remote_code=False, attn_implementation="eager")
    model.eval()

    class Encoder(torch.nn.Module):
        def __init__(self, base: torch.nn.Module):
            super().__init__()
            self.base = base

        def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor) -> torch.Tensor:
            hidden = self.base(input_ids=input_ids.long(), attention_mask=attention_mask.long()).last_hidden_state
            mask = attention_mask.unsqueeze(-1).to(hidden.dtype)
            pooled = (hidden * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1)
            return torch.nn.functional.normalize(pooled, p=2, dim=1)

    encoder = Encoder(model).eval()
    fixture = []
    with torch.no_grad():
        for key, role, text in SAMPLES:
            prefixed = f"{role}: {text}"
            tokens = tokenizer(prefixed, max_length=MAX_TOKENS, truncation=True,
                               padding="max_length", return_tensors="pt")
            vector = encoder(tokens["input_ids"], tokens["attention_mask"])[0].tolist()
            fixture.append({"id": key, "role": role, "text": prefixed,
                            "input_ids": tokens["input_ids"][0].tolist(),
                            "attention_mask": tokens["attention_mask"][0].tolist(),
                            "vector": vector})
    (output / "reference-vectors.json").write_text(json.dumps({
        "model_revision": LOCK["revision"], "max_tokens": MAX_TOKENS, "vectors": fixture,
    }, ensure_ascii=False, indent=2) + "\n")

    sample_ids = torch.tensor([fixture[0]["input_ids"]], dtype=torch.int32)
    sample_mask = torch.tensor([fixture[0]["attention_mask"]], dtype=torch.int32)
    with torch.no_grad():
        traced = torch.jit.trace(encoder, (sample_ids, sample_mask), strict=False)
        torch.testing.assert_close(traced(sample_ids, sample_mask), encoder(sample_ids, sample_mask),
                                   rtol=1e-4, atol=1e-4)
    converted = ct.convert(
        traced, convert_to="mlprogram", minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
        inputs=[ct.TensorType(name="input_ids", shape=(1, MAX_TOKENS), dtype=np.int32),
                ct.TensorType(name="attention_mask", shape=(1, MAX_TOKENS), dtype=np.int32)],
        outputs=[ct.TensorType(name="embedding", dtype=np.float32)],
    )
    fp16 = output / "e5-fp16.mlpackage"
    converted.save(str(fp16))
    quant_config = cto.coreml.OptimizationConfig(global_config=cto.coreml.OpLinearQuantizerConfig(
        mode="linear_symmetric", dtype=np.int8))
    compressed = cto.coreml.linear_quantize_weights(converted, config=quant_config)
    int8 = output / "e5-int8.mlpackage"
    compressed.save(str(int8))

    parity = {}
    for variant, candidate in (("fp16", converted), ("int8", compressed)):
        scores = {}
        for record in fixture:
            values = candidate.predict({
                "input_ids": np.asarray([record["input_ids"]], dtype=np.int32),
                "attention_mask": np.asarray([record["attention_mask"]], dtype=np.int32),
            })
            native = np.asarray(values["embedding"], dtype=np.float64).reshape(-1)
            reference = np.asarray(record["vector"], dtype=np.float64)
            if native.shape != reference.shape:
                raise ValueError(f"{variant}: wrong output dimension for {record['id']}: {native.shape}")
            cosine = float(np.dot(native, reference) / (np.linalg.norm(native) * np.linalg.norm(reference)))
            if not np.isfinite(cosine) or cosine < 0.99:
                raise ValueError(f"{variant}: reference cosine below 0.99 for {record['id']}: {cosine}")
            scores[record["id"]] = cosine
        parity[variant] = scores

    def package_size(path: Path) -> int:
        return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())

    manifest = {
        "repository": LOCK["repository"], "revision": LOCK["revision"],
        "license": LOCK["license"], "upstream_sha256": hashes,
        "platform": platform.platform(), "python": platform.python_version(),
        "coremltools": ct.__version__, "torch": torch.__version__,
        "transformers": transformers.__version__, "token_length": MAX_TOKENS,
        "pooling": "attention-mask mean; L2 normalization", "prefixes": ["query: ", "passage: "],
        "mac_coreml_reference_cosine": parity,
        "outputs": {
            "e5-fp16.mlpackage": {"bytes": package_size(fp16)},
            "e5-int8.mlpackage": {"bytes": package_size(int8)},
        },
    }
    (output / "conversion-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
