"""產生 luna_pinyin_ext.dict.yaml：官方 luna_pinyin 骨架 + 萌典層。

規則（說明見 README.md "How the dictionary is built"，中文見 README.zh-TW.md〈詞庫怎麼做的〉）：
  只收三字以上的詞。
  ü：萌典把 ü 寫成 u，逐字對照 terra_pinyin 同聲調讀音改寫；u 型、v 型都真實存在時兩種都收。
  A 官方沒有的詞 → 全收
  B 官方只有一讀、萌典的差異只在「兒」的前一音節（兒化怪癖） → 不收
  C 官方只有一讀、萌典讀音不同 → 收教育部讀音；詞只存在於 essay 時連官方讀音一起寫入，免得被取代
  只差 ü 拼法 → 不收（兩讀並收只用在官方沒有的詞，不拿來改官方讀音）
  D 其餘（官方本來就有多讀） → 不收

用法:
  python3 -I build_ext.py <terra_pinyin.taiwan.dict.yaml> <rime-data 目錄> <官方表反編譯.txt> <輸出 .dict.yaml>
"""
import os
import re
import sys
from collections import defaultdict
from itertools import product

moe_path, rime_data, official_path, out_path = sys.argv[1:]

HEADER = """\
# Rime dictionary
# encoding: utf-8
#
# 由 build_ext.py 產生，不要手改。
# 官方 luna_pinyin 骨架 + 萌典層（taiwandict-to-terrapinyin terra_pinyin.taiwan.dict.yaml）
# 手動補詞在 luna_pinyin_extra.dict.yaml，由 import_tables 帶入

---
name: luna_pinyin_ext
version: "2026.10.10"
sort: by_weight
use_preset_vocabulary: true
import_tables:
  - luna_pinyin
  - luna_pinyin_extra
...

"""


def body(path):
    in_body = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line == "...":
                in_body = True
                continue
            if in_body and line and not line.startswith("#"):
                yield line.split("\t")


# terra：字 -> {(u/v 正規化拼寫, 聲調): {實際拼寫}}
terra = defaultdict(lambda: defaultdict(set))
for cols in body(os.path.join(rime_data, "terra_pinyin.dict.yaml")):
    if len(cols) < 2 or len(cols[0]) != 1:
        continue
    m = re.fullmatch(r"([a-z]+)([1-5])", cols[1])
    if m:
        terra[cols[0]][(m.group(1).replace("v", "u"), m.group(2))].add(m.group(1))


def syllable_options(ch, syl):
    m = re.fullmatch(r"([a-z]+)([1-5])", syl)
    if not m:
        return None
    spell, tone = m.groups()
    opts = terra.get(ch, {}).get((spell.replace("v", "u"), tone))
    return sorted(opts) if opts else [spell]


official = defaultdict(set)
for cols in body(official_path):
    if len(cols) >= 2:
        official[cols[0]].add(cols[1])

# 官方 .dict.yaml 明確列出的詞：自建層讀音會疊加，不會取代
explicit = set()
for cols in body(os.path.join(rime_data, "luna_pinyin.dict.yaml")):
    if len(cols) >= 2:
        explicit.add(cols[0])

moe = defaultdict(set)
for cols in body(moe_path):
    if len(cols) < 2:
        continue
    word, syls = cols[0], cols[1].split()
    if len(word) < 3 or len(word) != len(syls):
        continue
    per = [syllable_options(c, s) for c, s in zip(word, syls)]
    if None in per:
        continue
    for combo in product(*per):
        moe[word].add(" ".join(combo))


def is_erhua_quirk(word, m, o):
    ms, os_ = m.split(), o.split()
    diff = [i for i, (a, b) in enumerate(zip(ms, os_)) if a != b]
    return bool(diff) and all(i + 1 < len(word) and word[i + 1] == "兒" for i in diff)


rows = []
stats = defaultdict(int)
for word in sorted(moe):
    O = official.get(word, set())
    if not O:
        for r in sorted(moe[word]):
            rows.append((word, r))
            stats["A"] += 1
        continue
    new = moe[word] - O
    if not new:
        continue
    if len(O) > 1:
        stats["D"] += len(new)
        continue
    (o,) = O
    c_added = False
    for r in sorted(new):
        if r.replace("v", "u") == o.replace("v", "u"):
            stats["uv_only"] += 1
            continue
        if is_erhua_quirk(word, r, o):
            stats["B"] += 1
            continue
        rows.append((word, r))
        stats["C"] += 1
        c_added = True
    if c_added and word not in explicit:
        rows.append((word, o))
        stats["C_official_kept"] += 1

with open(out_path, "w", encoding="utf-8") as f:
    f.write(HEADER)
    for w, r in rows:
        f.write(f"{w}\t{r}\n")

print(" ".join(f"{k}={stats[k]}" for k in ["A", "B", "C", "C_official_kept", "uv_only", "D"]))
