"""Reference token IDs for native-tokenizer parity (synthetic text only)."""
import json, re, sys, unicodedata
from pathlib import Path
from transformers import AutoTokenizer
corpus_swift, model_dir, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
texts = [m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
         for m in re.finditer(r'\("[^"]+", "(?:text|link)", "((?:[^"\\]|\\.)*)"\)', corpus_swift.read_text())]
texts = [t.replace("\\n", "\n") for t in texts]
edge = ["Cà phê ☕️ ngon 😂😂", "ＦＵＬＬ　ｗｉｄｔｈ １２３", unicodedata.normalize("NFD", "Tiếng Việt có dấu"),
        "nhiều     khoảng   trắng", "dòng 1\ndòng 2\tTab", "ﬁ ligature ① ½", "  đầu và cuối  ",
        "Ω≈ç√∫ 中文 日本語 한국어", "x" * 300, "", "a​b zero width", "OCR: ĐƠN GIÁ 35.000đ/ly"]
tok = AutoTokenizer.from_pretrained(model_dir, use_fast=True, local_files_only=True, trust_remote_code=False)
records = []
for i, t in enumerate(texts + edge):
    text = "passage: " + t
    records.append({"id": i, "text": text, "ids": tok(text, add_special_tokens=False)["input_ids"]})
out.write_text(json.dumps({"records": records}, ensure_ascii=False))
print(len(texts), "corpus +", len(edge), "edge; written", out)
