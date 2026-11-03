# Phase 01: multilingual-e5-small conversion candidate

This is an opt-in research script. The app does not bundle, download, or run this model until the Phase 01 quality and resource gates pass. It never reads `library.store` or uploads Noted content.

The model is [`intfloat/multilingual-e5-small`](https://huggingface.co/intfloat/multilingual-e5-small) at the commit and upstream file hashes in `model.lock.json`. The upstream model card declares MIT; the script copies the model card into the local output as attribution. Do not redistribute a converted model without checking the model's full notice and dependency licenses.

```sh
python3.11 -m venv /tmp/noted-e5-venv
/tmp/noted-e5-venv/bin/python -m pip install -r scripts/topic-model-evaluation/requirements.txt
/tmp/noted-e5-venv/bin/python scripts/topic-model-evaluation/export.py --output /tmp/noted-e5-spike
```

The export requests only safetensors, tokenizer and config files at the pinned commit, verifies the large-file SHA-256 values before loading, and never enables remote Python code. It emits `e5-fp16.mlpackage`, `e5-int8.mlpackage`, `tokenizer.json`, `sentencepiece.bpe.model`, `reference-vectors.json`, and `conversion-manifest.json`. The int8 variant compresses **weights**; this does not imply int8 activations or faster inference. Conversion may fail if Core ML Tools cannot convert an operator from this model; preserve the error as spike evidence rather than silently substituting another engine.

`reference-vectors.json` uses only synthetic Vietnamese/English phrases and records prefixed text, token IDs, attention masks and normalized Python reference vectors. The tokenizer is part of model semantics: before embedding real content on iOS, a native tokenizer must match these IDs exactly. A model package alone is insufficient. `compare_vectors.py` can compare native iOS vectors exported as JSON against the reference. Its result must reach cosine ≥0.99 for every fixture before the candidate is considered equivalent.

```sh
/tmp/noted-e5-venv/bin/python scripts/topic-model-evaluation/compare_vectors.py \
  /tmp/noted-e5-spike/reference-vectors.json /tmp/native-vectors.json
```

Expected native JSON: `{"vectors": [{"id": "vi-coffee", "input_ids": [...], "attention_mask": [...], "vector": [0.1, ...]}, ...]}`. The comparer requires matching token IDs and masks. No personal text should be committed. Model files and local outputs belong in `/tmp`, not the repository.

The reference encoder uses `query: ` for queries, `passage: ` for stored text, attention-mask mean pooling, and L2 normalization. Token length is fixed at 128 for this spike, below the model's 512-token maximum. Long-item chunking and score aggregation still require measurement against labeled data.

## Device spike (2026-11-03, iPhone 12 Pro)

Python 3.11 was not installed system-wide; an isolated interpreter works: `uv venv --python 3.11 <venv>` then `uv pip install --python <venv>/bin/python -r requirements.txt`.

1. Token-ID fixture over the synthetic corpus plus edge cases (synthetic text only):
   `<venv>/bin/python -I scripts/topic-model-evaluation/token_fixture.py Noted/Core/Intelligence/IntelligenceSyntheticCorpus.swift <hf-cache snapshot dir> <out>/token-fixture.json`
2. Compile: `xcrun coremlcompiler compile <out>/e5-int8.mlpackage <device-dir>` (same for fp16), and add `tokenizer.json`, `reference-vectors.json`, `token-fixture.json`.
3. Copy each file to the Debug app: `xcrun devicectl device copy to --device <UDID> --domain-type appDataContainer --domain-identifier <bundle id> --source <file> --destination "Library/Application Support/IntelligenceEvaluation/e5/<relative path>"`.
4. Run `IntelligenceEngineTests` on the device. The parity tests skip when files are absent; `TEST_RUNNER_NOTED_SPIKE_REPORT=1` also prints the synthetic-corpus report.

`CoreMLEmbeddingEngine` uses `.cpuAndNeuralEngine`: on iPhone 12 Pro the int8 model hit `LLVM ERROR: out of memory` with `.all`/`.cpuAndGPU`, and `.cpuOnly` returned NaN vectors.
