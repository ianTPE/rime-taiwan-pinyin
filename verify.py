"""比對官方表與建好的 luna_pinyin_ext 表：當集合逐筆比，不只看總數。

用法: python3 -I verify.py <官方表反編譯.txt> <ext 表反編譯.txt>
"""
import sys

official_path, built_path = sys.argv[1:]


def load(path):
    pairs, weights, rows, in_body = set(), {}, 0, False
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line == "...":
                in_body = True
                continue
            if in_body and "\t" in line:
                cols = line.split("\t")
                key = (cols[0], cols[1])
                rows += 1
                pairs.add(key)
                weights[key] = cols[2] if len(cols) > 2 else ""
    return pairs, weights, rows


o, ow, orows = load(official_path)
b, bw, brows = load(built_path)

lost = o - b
dup = brows - len(b)
wchg = [k for k in o & b if ow[k] != bw[k]]
print(f"num_entries 官方 {orows} → ext {brows}（新增 {brows - orows}）")
print(f"官方讀音被擠掉 {len(lost)}，重複列 {dup}，官方權重被改 {len(wchg)}")

checks = [
    ("天秤座", "tian cheng zuo"), ("天秤座", "tian ping zuo"),
    ("頸椎", "jing zhui"), ("白臉兒", "bai lian er"),
    ("綠衣黃裡", "lu yi huang li"), ("綠衣黃裡", "lv yi huang li"),
    ("學測", "xue ce"), ("機場捷運", "ji chang jie yun"),
]
missing = [k for k in checks if k not in b]
print("抽驗：" + ("全數在表" if not missing else f"缺 {missing}"))

sys.exit(1 if lost or dup or wchg or missing else 0)
