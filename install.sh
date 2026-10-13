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
# fcitx5-chinese-addons 會連帶裝 QtWebEngine，只裝拼音本體
python3 -c "import gi" 2>/dev/null || { echo "缺少 python3-gi（apt install python3-gi），設定切換鍵要用" >&2; exit 1; }
dpkg -s fcitx5-pinyin >/dev/null 2>&1 || { echo "缺少 fcitx5 拼音（sudo apt install --no-install-recommends fcitx5-pinyin fcitx5-module-cloudpinyin）" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "== 下載萌典來源（$SRC_COMMIT）"
git clone -q "$SRC_REPO" "$TMP/src"
git -C "$TMP/src" checkout -q "$SRC_COMMIT"

echo "== 反編譯官方表"
rime_table_decompiler "$RIME_DATA/build/luna_pinyin.table.bin" "$TMP/official.txt" >/dev/null 2>&1

echo "== 產生 luna_pinyin_ext.dict.yaml"
python3 -I "$HERE/build_ext.py" "$TMP/src/terra_pinyin.taiwan.dict.yaml" "$RIME_DATA" \
  "$TMP/official.txt" "$HERE/luna_pinyin_ext.dict.yaml"

echo "== 舊的自建檔案搬到 rime-disabled（不刪除）"
mkdir -p "$USER_DIR"
BACKUP=$HOME/.local/share/fcitx5/rime-disabled/$(date +%Y%m%d-%H%M%S)
for f in luna_pinyin_tw.schema.yaml luna_pinyin_simp.schema.yaml luna_pinyin.moedict.dict.yaml \
         luna_pinyin_ext.dict.yaml luna_pinyin_extra.dict.yaml luna_pinyin_tw.custom.yaml luna_pinyin_simp.custom.yaml default.custom.yaml; do
  [ -f "$USER_DIR/$f" ] || continue
  [ -f "$HERE/$f" ] && cmp -s "$USER_DIR/$f" "$HERE/$f" && continue
  mkdir -p "$BACKUP"
  mv "$USER_DIR/$f" "$BACKUP/"
  echo "   $f → $BACKUP/"
done
others=$(cd "$USER_DIR" && ls *.dict.yaml 2>/dev/null | grep -vxE "luna_pinyin_(ext|extra).dict.yaml" || true)
[ -n "$others" ] && echo "   注意：使用者目錄還有其他詞庫檔，未處理：$others"

cp "$HERE"/{luna_pinyin_ext.dict.yaml,luna_pinyin_extra.dict.yaml,luna_pinyin_tw.custom.yaml,default.custom.yaml} "$USER_DIR/"

echo "== 部署"
rime_deployer --build "$USER_DIR" "$RIME_DATA" "$USER_DIR/build" >/dev/null 2>&1

echo "== 驗證"
rime_table_decompiler "$USER_DIR/build/luna_pinyin_ext.table.bin" "$TMP/ext.txt" >/dev/null 2>&1
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
