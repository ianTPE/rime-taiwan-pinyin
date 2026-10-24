#!/usr/bin/env bash
# 在 Debian / KDE Wayland 上裝好輸入法：繁體用 fcitx5-rime 的臺灣方案（luna_pinyin_ext 詞庫），簡體用 fcitx5 拼音。
# Rime 方案清單只列 luna_pinyin_tw。
# 每台機器跑同一支，產出的 luna_pinyin_ext.dict.yaml 會寫回本目錄：git diff 有變化就代表來源或官方詞庫版本不同。
# 用法: ./install.sh
set -euo pipefail

SRC_REPO=https://github.com/taichunmin/taiwandict-to-terrapinyin.git
SRC_COMMIT=245ca8c
HERE=$(cd "$(dirname "$0")" && pwd)
RIME_DATA=/usr/share/rime-data
USER_DIR=$HOME/.local/share/fcitx5/rime

for cmd in git python3 rime_deployer rime_table_decompiler; do
  command -v "$cmd" >/dev/null || { echo "缺少 $cmd（apt install fcitx5-rime librime-bin git python3）" >&2; exit 1; }
done
[ -f "$RIME_DATA/terra_pinyin.dict.yaml" ] || { echo "缺少 terra_pinyin（apt install rime-data-terra-pinyin）" >&2; exit 1; }
for f in build/luna_pinyin.table.bin luna_pinyin_tw.schema.yaml; do
  [ -f "$RIME_DATA/$f" ] || { echo "缺少 $RIME_DATA/$f（apt install rime-data-luna-pinyin）" >&2; exit 1; }
done
# fcitx5-chinese-addons 會連帶裝 QtWebEngine，只裝拼音本體
python3 -c "import gi" 2>/dev/null || { echo "缺少 python3-gi（apt install python3-gi），設定切換鍵要用" >&2; exit 1; }
dpkg -s fcitx5-pinyin >/dev/null 2>&1 || { echo "缺少 fcitx5 拼音（sudo apt install --no-install-recommends fcitx5-pinyin fcitx5-module-cloudpinyin）" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 輸出平常不印，失敗時印最後 20 行再結束，不要靜默退出
quiet() {
  "$@" >"$TMP/cmd.log" 2>&1 || { tail -n 20 "$TMP/cmd.log" >&2; echo "失敗：$*" >&2; exit 1; }
}

echo "== 下載萌典來源（$SRC_COMMIT）"
git clone -q "$SRC_REPO" "$TMP/src"
git -C "$TMP/src" checkout -q "$SRC_COMMIT"

echo "== 反編譯官方表"
quiet rime_table_decompiler "$RIME_DATA/build/luna_pinyin.table.bin" "$TMP/official.txt"

echo "== 產生 luna_pinyin_ext.dict.yaml"
python3 -I "$HERE/build_ext.py" "$TMP/src/terra_pinyin.taiwan.dict.yaml" "$RIME_DATA" \
  "$TMP/official.txt" "$HERE/luna_pinyin_ext.dict.yaml"

echo "== 舊的自建檔案搬到 rime-disabled（不刪除）"
mkdir -p "$USER_DIR"
BACKUP=$HOME/.local/share/fcitx5/rime-disabled/$(date +%Y%m%d-%H%M%S)
for f in luna_pinyin_tw.schema.yaml luna_pinyin_simp.schema.yaml luna_pinyin.moedict.dict.yaml \
         luna_pinyin_ext.dict.yaml luna_pinyin_extra.dict.yaml luna_pinyin_tw.custom.yaml luna_pinyin_simp.custom.yaml; do
  [ -f "$USER_DIR/$f" ] || continue
  [ -f "$HERE/$f" ] && cmp -s "$USER_DIR/$f" "$HERE/$f" && continue
  mkdir -p "$BACKUP"
  mv "$USER_DIR/$f" "$BACKUP/"
  echo "   $f → $BACKUP/"
done
others=$(cd "$USER_DIR" && ls *.dict.yaml 2>/dev/null | grep -vxE "luna_pinyin_(ext|extra).dict.yaml" || true)
[ -n "$others" ] && echo "   注意：使用者目錄還有其他詞庫檔，未處理：$others"

cp "$HERE"/{luna_pinyin_ext.dict.yaml,luna_pinyin_extra.dict.yaml,luna_pinyin_tw.custom.yaml} "$USER_DIR/"

# default.custom.yaml 只合併 schema_list，其他設定（如 menu/page_size）保留；看不懂的寫法就停下來，不亂改
if [ -f "$USER_DIR/default.custom.yaml" ]; then
  python3 -I - "$USER_DIR/default.custom.yaml" "$BACKUP" <<'PY'
import os, re, shutil, sys
path, backup = sys.argv[1:]
old = open(path, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in old else "\n"
lines = re.split(r"\r?\n", old.rstrip("\r\n"))
block = ["  schema_list:", "    - schema: luna_pinyin_tw"]

def merged(lines):
    p = next((i for i, l in enumerate(lines) if re.match(r"patch:\s*(#.*)?$", l)), None)
    if p is None:
        if any(re.match(r"\s*[^#\s]", l) for l in lines):
            sys.exit("看不懂 default.custom.yaml（沒有頂格的 patch:），請手動把 schema_list 加進去，見本目錄的 default.custom.yaml。")
        return [l for l in lines if l] + ["patch:"] + block
    # patch 區塊到下一個頂格的非註解行為止
    end = next((i for i in range(p + 1, len(lines)) if re.match(r"[^\s#]", lines[i])), len(lines))
    k = next((i for i in range(p + 1, end) if re.match(r'\s+"?schema_list"?\s*:', lines[i])), None)
    if k is None:
        return lines[:p + 1] + block + lines[p + 1:]
    ind, rest = re.match(r'(\s+)"?schema_list"?\s*:(.*)$', lines[k]).groups()
    rest = re.sub(r"#.*$", "", rest).strip()
    j = k + 1
    if rest == "":
        # 區塊寫法：舊的清單項目是縮排更深、或同縮排以 - 開頭的行
        item = re.compile(re.escape(ind) + r"(\s+\S|-)")
        while j < end and item.match(lines[j]):
            j += 1
    elif not re.fullmatch(r"\[.*\]", rest):
        sys.exit("看不懂 default.custom.yaml 的 schema_list 寫法，請手動改成只有 luna_pinyin_tw。")
    return lines[:k] + [ind + b[2:] for b in block] + lines[j:]

new = nl.join(merged(lines)) + nl
if new != old:
    os.makedirs(backup, exist_ok=True)
    shutil.copy2(path, backup)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(new)
    print(f"   default.custom.yaml 舊檔備份到 {backup}/，只改了 schema_list")
PY
else
  cp "$HERE/default.custom.yaml" "$USER_DIR/"
fi

echo "== 部署"
quiet rime_deployer --build "$USER_DIR" "$RIME_DATA" "$USER_DIR/build"

echo "== 驗證"
quiet rime_table_decompiler "$USER_DIR/build/luna_pinyin_ext.table.bin" "$TMP/ext.txt"
python3 -I "$HERE/verify.py" "$TMP/official.txt" "$TMP/ext.txt"

# KDE Wayland 下不要重啟 fcitx5（重啟後回不到 KWin 底下），用熱重載
if command -v dbus-send >/dev/null && dbus-send --session --print-reply --dest=org.fcitx.Fcitx5 \
     /controller org.fcitx.Fcitx.Controller1.Refresh >/dev/null 2>&1; then
  dbus-send --session --print-reply --dest=org.fcitx.Fcitx5 /controller \
    org.fcitx.Fcitx.Controller1.ReloadAddonConfig string:"rime" >/dev/null
  # 輸入法清單：英文、Rime（繁體）、拼音（簡體）。不手改 profile，執行中的 fcitx5 結束時會覆寫它
  gdbus call --session --dest org.fcitx.Fcitx5 --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo \
    "Default" "us" "[('keyboard-us',''),('rime',''),('pinyin','')]" >/dev/null
  dbus-send --session --print-reply --dest=org.fcitx.Fcitx5 /controller \
    org.fcitx.Fcitx.Controller1.Save >/dev/null
  # Super+Space 依序輪替輸入法（同 Windows 的 Win+Space）；原本綁的「切換群組」只有一個群組時用不到，拿掉。走 DBus，執行中的 fcitx5 才不會覆寫
  python3 -I - <<'PY'
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
def tov(x):
    return GLib.Variant("a{sv}", {k: tov(v) for k, v in x.items()}) if isinstance(x, dict) else GLib.Variant("s", str(x))
def patch(uri, edit):
    cfg, _ = bus.call_sync("org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1", "GetConfig",
                           GLib.Variant("(s)", (uri,)), GLib.VariantType("(va(sa(sssva{sv})))"), 0, -1, None).unpack()
    edit(cfg)
    bus.call_sync("org.fcitx.Fcitx5", "/controller", "org.fcitx.Fcitx.Controller1", "SetConfig",
                  GLib.Variant("(sv)", (uri, tov(cfg))), None, 0, -1, None)
patch("fcitx://config/global", lambda c: c["Hotkey"].update(
    EnumerateForwardKeys={"0": "Super+space"}, EnumerateBackwardKeys={"0": "Shift+Super+space"},
    EnumerateGroupForwardKeys={}, EnumerateGroupBackwardKeys={}))
# 拼音負責簡體：關掉簡繁轉換（chttrans）對任何輸入法的套用。Ctrl+Shift+F 會把它打開，從舊機複製來的設定也可能帶著
patch("fcitx://config/addon/chttrans", lambda c: c.update(EnabledIM={}))
PY
  echo "== fcitx5 已熱重載，輸入法清單：英文、Rime、拼音；Super+Space 切換輸入法；拼音不轉繁體"
else
  echo "== fcitx5 沒在跑：詞庫下次登入生效，輸入法清單要登入後再跑一次本腳本"
fi
