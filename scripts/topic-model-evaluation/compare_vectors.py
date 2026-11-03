#!/usr/bin/env python3
"""Check iOS E5 output against the pinned, synthetic Python reference fixture."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def cosine(a: list[float], b: list[float]) -> float:
    if len(a) != len(b) or not a:
        raise ValueError("Vector dimensions differ or are empty")
    numerator = math.fsum(x * y for x, y in zip(a, b))
    a_norm = math.sqrt(math.fsum(x * x for x in a))
    b_norm = math.sqrt(math.fsum(y * y for y in b))
    if a_norm == 0 or b_norm == 0:
        raise ValueError("Zero-length vector")
    return numerator / (a_norm * b_norm)


def compare(reference: dict, native: dict, threshold: float = 0.99) -> dict[str, float]:
    expected = {row["id"]: row for row in reference["vectors"]}
    actual = {row["id"]: row for row in native["vectors"]}
    if set(expected) != set(actual) or len(actual) != len(native["vectors"]):
        raise ValueError("Native fixture IDs must exactly match reference IDs")
    scores = {}
    for key, row in expected.items():
        measured = actual[key]
        if measured.get("input_ids") != row["input_ids"]:
            raise ValueError(f"Tokenizer IDs differ for {key}")
        if measured.get("attention_mask") != row["attention_mask"]:
            raise ValueError(f"Attention mask differs for {key}")
        score = cosine(row["vector"], measured["vector"])
        if not math.isfinite(score) or score < threshold:
            raise ValueError(f"Cosine below {threshold} for {key}: {score}")
        scores[key] = score
    return scores


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("native", type=Path)
    args = parser.parse_args()
    scores = compare(json.loads(args.reference.read_text()), json.loads(args.native.read_text()))
    print(json.dumps({"minimum_cosine": min(scores.values()), "cosine_by_id": scores}, indent=2))


if __name__ == "__main__":
    main()
