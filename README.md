# rime-taiwan-pinyin

**Type Taiwan-standard Traditional Chinese with Hanyu Pinyin** — on Linux (fcitx5) and Windows (Weasel), with one shared configuration and dictionary.

[中文說明](README.zh-TW.md)

## Who this is for

If you live in Taiwan, or write for Taiwanese readers, and you type with **pinyin** rather than zhuyin, your options have been poor:

| What you use | What goes wrong |
|---|---|
| Microsoft Bopomofo with a pinyin keyboard layout | It maps pinyin onto Taiwan's official zhuyin readings one-to-one: `qi2` won't give 期 (you need `qi1`), and long input without tones gets segmented wrongly. It is zhuyin in disguise, not a pinyin engine |
| Microsoft Pinyin with "Traditional output" | A good engine, but the output is mainland-style Traditional (綫 instead of 線, 裏 instead of 裡), with mainland vocabulary and frequencies |
| Natural Input (自然輸入法) pinyin mode | Best Taiwan vocabulary, but paid, and its settings can't be shared with Linux |
| Rime (Weasel / fcitx5-rime) | Free, a strong engine, configs shared across Linux and Windows — but you have to set it up yourself: the default Luna Pinyin doesn't output Taiwan-standard glyphs, and its dictionary lacks recent Taiwanese terms |

This repo does the Rime setup for you:

- **Taiwan-standard glyphs.** Switches to Rime's built-in (but non-default) "Luna Pinyin · Taiwan" schema, which runs output through OpenCC `t2tw` (e.g. 爲 → 為, 裏 → 裡). It is the only schema in the list.
- **Fills dictionary gaps.** The official dictionary already has everyday Taiwanese words (捷運, 軟體, 悠遊卡). What's missing are recent abbreviations, names and brands, plus idioms and proverbs from the Ministry of Education dictionaries.
- **Ministry of Education readings work too**, alongside the official ones: 鱗次櫛比 comes up for both `lin ci zhi bi` and `lin ci jie bi`.
- **One script per OS.** Traditional goes through Rime; Simplified is left to the system pinyin IME (Fcitx5 Pinyin on Linux, Microsoft Pinyin on Windows). Switch with `Super+Space` / `Win+Space`.

## Install

### Windows (Weasel)

1. Install Weasel from [rime.im](https://rime.im/). In Settings → Time & language → Language & region, check that 小狼毫 is in the Chinese keyboard list (sign out and back in if not).
2. Download this repo (Code → Download ZIP), unzip, open PowerShell in the folder and run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   It copies four files into `%APPDATA%\Rime` (backing up any that differ), redeploys, and checks that the Taiwan schema picked up the dictionary.

3. For Simplified, add "Chinese (Simplified, China)" with Microsoft Pinyin and switch with `Win+Space`.

Prefer not to run a script? Copy `luna_pinyin_ext.dict.yaml`, `luna_pinyin_extra.dict.yaml`, `luna_pinyin_tw.custom.yaml` and `default.custom.yaml` into `%APPDATA%\Rime`, then right-click the IME tray icon → 重新部署 (Redeploy). Copy the files as they are; don't open and re-save them in Notepad.

**If "朙月拼音·臺灣正體" doesn't show up after deploying**, your Weasel build may not ship `luna_pinyin_tw.schema.yaml` (0.17.4 does). Copy it from `/usr/share/rime-data/` on any Linux machine with `rime-data-luna-pinyin`, or from [rime/rime-luna-pinyin](https://github.com/rime/rime-luna-pinyin), into `%APPDATA%\Rime` and redeploy. Deploy errors don't pop up; they are logged under `%TEMP%\rime.weasel\`. A long list of `Encode failure` warnings there is normal.

For a horizontal candidate list, put this in `%APPDATA%\Rime\weasel.custom.yaml` and redeploy:

```yaml
patch:
  style/horizontal: true
```

### Linux (Debian / KDE Wayland, fcitx5)

1. Install packages:

   ```bash
   sudo apt install fcitx5-rime librime-bin rime-data-luna-pinyin rime-data-terra-pinyin git python3 python3-gi
   sudo apt install --no-install-recommends fcitx5-pinyin fcitx5-module-cloudpinyin
   ```

   The second line is Fcitx5 Pinyin for Simplified; `--no-install-recommends` avoids pulling in the large QtWebEngine.

2. On KDE Wayland, choose **Fcitx 5 Wayland Launcher** under System Settings → Keyboard → Virtual Keyboard, then sign out and back in. Check:

   ```bash
   grep InputMethod ~/.config/kwinrc
   ps -o comm= -p "$(ps -o ppid= -p "$(pgrep -f fcitx5-wayland-launcher)")"
   ```

   The first should point to `fcitx5-wayland-launcher.desktop`, the second should print `kwin_wayland`. (`fcitx5` itself showing `systemd` as its parent is normal.)

   **Don't `pkill fcitx5`** — under KDE Wayland only a KWin-launched fcitx5 can attach to input, and you'd need to sign in again.

3. From a logged-in desktop session:

   ```bash
   git clone https://github.com/ianTPE/rime-taiwan-pinyin.git
   cd rime-taiwan-pinyin
   ./install.sh
   ```

   The script downloads the MoE dictionary source (pinned commit), builds the dictionary, moves old self-built files to `~/.local/share/fcitx5/rime-disabled/` (never deletes), deploys, verifies entry by entry, and sets the fcitx5 IME list (English, Rime, Pinyin) and the `Super+Space` hotkey. On success it ends with:

   ```
   官方讀音被擠掉 0，重複列 0，官方權重被改 0
   == fcitx5 已熱重載，輸入法清單：英文、Rime、拼音；Super+Space 切換輸入法；拼音不轉繁體
   ```

   (Official readings dropped 0, duplicates 0, official weights changed 0; fcitx5 reloaded.) If it says fcitx5 isn't running, run it again from a logged-in desktop.

## Check it works

| IME | Type | Expect |
|---|---|---|
| Rime / Weasel | `ruan ti` | 軟體 |
| Rime / Weasel | `xue ce`, `wei fu bu` | 學測, 衛福部 (hand-added words loaded) |
| Rime / Weasel | `lin ci jie bi` | 鱗次櫛比 (MoE layer loaded) |
| Fcitx5 Pinyin / Microsoft Pinyin | `ruan jian` | 软件 |

Rime's schema menu (`` Ctrl+` `` or F4) should list only 朙月拼音·臺灣正體.

## How the dictionary is built

`luna_pinyin_ext` has three layers, about 500,000 entries once compiled:

| Layer | Entries | What |
|---|---|---|
| Official `luna_pinyin` (incl. the essay corpus) | 498,855 | The backbone, untouched; imported from the system copy at deploy time |
| MoE: words missing from the official dictionary | 2,407 | Mostly idioms and proverbs |
| MoE: Ministry of Education readings | 88 | Added alongside the official reading, so both spellings work |
| Hand-added `luna_pinyin_extra` | a few | Recent Taiwanese terms, names and brands found in neither source |

Decisions that came from measurement rather than assumption:

- **Don't replace the official backbone.** It is more complete than it looks, and stacking a whole second dictionary on top pushed correct official readings out. MoE only fills words the official dictionary lacks.
- **MoE readings coexist with official ones instead of overriding them.** The official dictionary has some wrong readings, but so does any self-built layer; keeping both is the safe choice.
- **Erhua quirks are filtered out.** A batch of MoE readings differs only in the syllable before 兒; including them did more harm than good.
- **Three characters or more only.** One- and two-character words are already covered.

The rules live in `build_ext.py`. `verify.py` compares the official and built tables as sets, entry by entry: no official reading lost, no duplicate rows, no official weight changed.

### Adding your own words

Edit `luna_pinyin_extra.dict.yaml`, one word per line: `word<Tab>pinyin<Tab>500`. Only add words the official dictionary lacks — listing an existing word again replaces its official readings. Then rerun `./install.sh` (Linux) or `install.ps1` (Windows).

## Tested on

- Linux: two Debian 13 / KDE Wayland machines, byte-identical dictionary output. Not tested on other distributions, desktops, or X11.
- Windows: Windows 11, Weasel 0.17.4.

Provided as is; issues welcome, ongoing maintenance not guaranteed.

## License and sources

- Scripts and config: MIT ([LICENSE](LICENSE)).
- MoE entries in `luna_pinyin_ext.dict.yaml`: from the R.O.C. Ministry of Education's 《重編國語辭典修訂本》, 《國語辭典簡編本》, 《國語小字典》 and 《成語典》, released under [CC BY-ND 3.0 TW](https://creativecommons.org/licenses/by-nd/3.0/tw/). Per the Ministry, "no derivatives" applies to the text itself, not to format conversion.
- Conversion to Rime format: [taichunmin/taiwandict-to-terrapinyin](https://github.com/taichunmin/taiwandict-to-terrapinyin) (MIT), pinned at `245ca8c`.
- Official dictionary and schemas: [Rime](https://rime.im/) `luna_pinyin` / `luna_pinyin_tw` (LGPL-3.0), not bundled — the system copy is used.
