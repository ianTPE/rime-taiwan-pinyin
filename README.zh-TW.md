# rime-taiwan-pinyin

**用漢語拼音打臺灣正體字、臺灣用語。**Linux（fcitx5）與 Windows（小狼毫）都能用，兩邊是同一套設定和詞庫。

[English](README.md)

## 你是不是也遇到這些問題

在臺灣用拼音打字的人，能選的路一直很少：

| 你用的 | 會發生什麼事 |
|---|---|
| 微軟注音，鍵盤改成拼音 | 讀音照臺灣審定音一對一轉，`qi2` 打不出「期」，要打 `qi1`；不打聲調，長句會斷錯。它是注音換一層拼音鍵盤，不是拼音輸入法 |
| 微軟拼音，開「輸出繁體」 | 拼音引擎很好，但輸出的是大陸繁體：「線」變「綫」、「裡」變「裏」，詞頻和詞彙都是大陸的 |
| 自然輸入法拼音模式 | 臺灣詞彙最完整，但要付費，設定不能跟 Linux 共用 |
| Rime（小狼毫、fcitx5-rime） | 免費、引擎好、Linux 和 Windows 設定共用，但要自己摸索：預設的朙月拼音輸出的不是臺灣慣用字形，詞庫也缺臺灣的新詞 |

這個 repo 走最後一條，把摸索的部分做完：

- **字形用臺灣正體。**改用 Rime 內建、但不是預設的「朙月拼音·臺灣正體」方案，輸出時經過 OpenCC `t2tw`，轉成臺灣慣用字形（例如「爲」→「為」、「裏」→「裡」）。方案清單只留這一個。
- **補上官方詞庫沒有的詞。**官方詞庫其實已經有捷運、軟體、悠遊卡、板南線這類日常用語；缺的是較新的縮寫、人名、品牌，以及教育部辭典裡的成語諺語。這些由下面兩層補上。
- **教育部讀音也打得出來。**例如「鱗次櫛比」，打 `lin ci zhi bi` 或 `lin ci jie bi` 都出得來。
- **Linux 和 Windows 一個腳本裝好。**繁體用 Rime，簡體交給系統的拼音輸入法（Linux 的 Fcitx5 拼音、Windows 的微軟拼音），`Super+Space`／`Win+Space` 切換。

| 打 | 官方詞庫 | 裝了之後 |
|---|---|---|
| `xue ce`、`wei fu bu`、`ji chang jie yun` | 沒有這些詞 | 學測、衛福部、機場捷運 |
| `lin ci jie bi` | 只收 `lin ci zhi bi` 一種讀音 | 教育部讀音也出「鱗次櫛比」 |

## 安裝

### Windows（小狼毫）

1. 從 [rime.im](https://rime.im/) 下載安裝小狼毫。到「設定 → 時間與語言 → 語言與地區」，確認中文的鍵盤清單裡有「小狼毫」。沒有的話登出再登入。
2. 下載本 repo（綠色 Code 按鈕 → Download ZIP，解壓縮），在資料夾裡開 PowerShell，執行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```

   腳本會把四個檔案複製到 `%APPDATA%\Rime`（內容不同的舊檔先備份）、重新部署，並檢查臺灣正體方案有沒有接上詞庫。

3. 要打簡體時，用 Windows 內建的微軟拼音：「語言與地區」新增「中文（簡體，中國）」，`Win+Space` 切換。

不想跑腳本，也可以手動把 `luna_pinyin_ext.dict.yaml`、`luna_pinyin_extra.dict.yaml`、`luna_pinyin_tw.custom.yaml`、`default.custom.yaml` 複製到 `%APPDATA%\Rime`，再在右下角輸入法圖示按右鍵 →「重新部署」。用複製的，不要用記事本開來另存。

**部署後方案清單裡沒有「朙月拼音·臺灣正體」時**：你的小狼毫版本可能沒附 `luna_pinyin_tw.schema.yaml`（0.17.4 有附）。從裝了 `rime-data-luna-pinyin` 的 Linux 機器的 `/usr/share/rime-data/`，或 [rime/rime-luna-pinyin](https://github.com/rime/rime-luna-pinyin) 複製一份到 `%APPDATA%\Rime`，再重新部署。部署失敗不會跳錯，只寫在 `%TEMP%\rime.weasel\` 的日誌裡；日誌裡一長串 `Encode failure` 是正常的。

選字框想改成橫排：在 `%APPDATA%\Rime\weasel.custom.yaml` 寫入下面兩行，再重新部署。

```yaml
patch:
  style/horizontal: true
```

### Linux（Debian / KDE Wayland，fcitx5）

1. 裝套件：

   ```bash
   sudo apt install fcitx5-rime librime-bin rime-data-luna-pinyin rime-data-terra-pinyin git python3 python3-gi
   sudo apt install --no-install-recommends fcitx5-pinyin fcitx5-module-cloudpinyin
   ```

   第二行是簡體用的 Fcitx5 拼音；加 `--no-install-recommends` 是為了不連帶裝很大的 QtWebEngine。

2. KDE Wayland：到「系統設定 → 鍵盤 → 虛擬鍵盤」選 **Fcitx 5 Wayland Launcher**，登出再登入。之後確認：

   ```bash
   grep InputMethod ~/.config/kwinrc
   ps -o comm= -p "$(ps -o ppid= -p "$(pgrep -f fcitx5-wayland-launcher)")"
   ```

   第一行應指向 `fcitx5-wayland-launcher.desktop`，第二行應印出 `kwin_wayland`。`fcitx5` 本身的父進程顯示為 `systemd` 是正常的。

   **不要 `pkill fcitx5`。**KDE Wayland 下只有 KWin 啟動的 fcitx5 接得上輸入法，砍掉要重新登入才能恢復。

3. 在已登入的桌面裡執行：

   ```bash
   git clone https://github.com/ianTPE/rime-taiwan-pinyin.git
   cd rime-taiwan-pinyin
   ./install.sh
   ```

   腳本會下載萌典來源（鎖在固定版本）、產生詞庫、把舊的自建檔案搬到 `~/.local/share/fcitx5/rime-disabled/`（只搬不刪）、部署、逐筆驗證，最後設定輸入法清單（英文、Rime、拼音）與 `Super+Space` 切換鍵。成功時最後會印出：

   ```
   官方讀音被擠掉 0，重複列 0，官方權重被改 0
   == fcitx5 已熱重載，輸入法清單：英文、Rime、拼音；Super+Space 切換輸入法；拼音不轉繁體
   ```

   如果印的是「fcitx5 沒在跑」，登入桌面後再跑一次。

## 驗證

| 輸入法 | 打 | 應該出現 |
|---|---|---|
| Rime／小狼毫 | `ruan ti` | 軟體 |
| Rime／小狼毫 | `jie yun`、`you you ka`、`ban nan xian` | 捷運、悠遊卡、板南線 |
| Rime／小狼毫 | `xue ce`、`wei fu bu` | 學測、衛福部（手動補詞有載入） |
| Rime／小狼毫 | `lin ci jie bi`、`lin ci zhi bi` | 兩種都出「鱗次櫛比」（萌典層有載入） |
| Fcitx5 拼音／微軟拼音 | `ruan jian` | 软件 |

Rime 的方案清單（`` Ctrl+` `` 或 F4）只應該有「朙月拼音·臺灣正體」一項。

## 詞庫怎麼做的

詞庫 `luna_pinyin_ext` 分三層，編譯後約 50 萬筆：

| 層 | 筆數 | 內容 |
|---|---|---|
| 官方 `luna_pinyin`（含 essay 語料） | 498,855 | 骨架，一筆不動，安裝時直接引用系統的官方檔 |
| 萌典：官方沒有的詞 | 2,407 | 教育部辭典裡官方詞庫沒收的詞，多半是成語、諺語 |
| 萌典：教育部讀音 | 88 | 跟官方讀音並存，兩種讀法都打得出來 |
| 手動補詞 `luna_pinyin_extra` | 少量 | 官方與萌典都沒收的臺灣用語、人名、品牌 |

幾個做法是量測後才決定的：

- **官方骨架不換掉。**官方詞庫比想像中完整；自己疊一整層詞庫上去，反而會把官方的正確讀音擠掉。所以萌典只補官方沒有的詞。
- **教育部讀音跟官方讀音並存，不取代。**官方有錯讀音，但自建層自己也有錯；並存最安全，兩種都打得出來。
- **兒化讀音先濾掉。**萌典有一批差異只在「兒」前一音節的讀音，收進來弊大於利。
- **只收三字以上的詞。**一兩個字的詞，官方都有了。

規則寫在 `build_ext.py`，`verify.py` 會把官方表和建好的表當集合逐筆比對：官方讀音有沒有被擠掉、有沒有重複列、官方權重有沒有被改。

### 自己加詞

改 `luna_pinyin_extra.dict.yaml`，一行一個詞：`詞<Tab>拼音<Tab>500`。只加官方沒有的詞——官方已經有的詞再列一次，會整詞取代官方讀音。改完：

- Linux：再跑一次 `./install.sh`。
- Windows：再跑一次 `install.ps1`。

## 實測範圍

- **Linux**：兩台 Debian 13 / KDE Wayland，產出的詞庫一字不差。沒有在其他發行版、其他桌面環境或 X11 下測過；安裝第 2 步只適用 KDE Wayland。
- **Windows**：Windows 11、小狼毫 0.17.4。
- 只測過建置當天的抽驗，沒有長期使用的體感資料。

有問題歡迎開 issue。本 repo 依現況提供，不保證持續維護。

## 授權與來源

- 腳本與設定檔：MIT，見 [LICENSE](LICENSE)。
- `luna_pinyin_ext.dict.yaml` 裡的萌典詞條：來自中華民國教育部《重編國語辭典修訂本》、《國語辭典簡編本》、《國語小字典》與《成語典》，採 [創用CC 姓名標示-禁止改作 3.0 臺灣](https://creativecommons.org/licenses/by-nd/3.0/tw/) 授權釋出（[公眾授權頁](http://resources.publicense.moe.edu.tw/dict_reviseddict_download.html)）。依教育部的解釋，禁止改作的對象是文字資料本身，不限制格式轉換。
- 萌典資料轉成 Rime 格式：[taichunmin/taiwandict-to-terrapinyin](https://github.com/taichunmin/taiwandict-to-terrapinyin)（MIT），`install.sh` 鎖在 commit `245ca8c`。
- 官方詞庫與方案：[Rime](https://rime.im/) 的 `luna_pinyin`、`luna_pinyin_tw`（LGPL-3.0），本 repo 不附，安裝時使用系統裡的版本。
