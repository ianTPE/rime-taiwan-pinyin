# 在 Windows 上裝好小狼毫（Weasel）的臺灣正體拼音：複製設定與詞庫、重新部署、檢查方案有沒有接上詞庫。
# 小狼毫要先裝好（https://rime.im/）。簡體請用 Windows 內建的微軟拼音，本腳本不處理。
# 用法（PowerShell，在本目錄執行）: .\install.ps1
$ErrorActionPreference = 'Stop'

$Here = $PSScriptRoot
$Files = 'luna_pinyin_ext.dict.yaml', 'luna_pinyin_extra.dict.yaml', 'luna_pinyin_tw.custom.yaml'

# 把 default.custom.yaml 的 patch 底下 schema_list 換成只有 luna_pinyin_tw，其他行（如 menu/page_size）原樣保留。
# 看不懂的寫法就丟錯，不亂改。
function Set-SchemaList([string[]]$Lines) {
  $block = '  schema_list:', '    - schema: luna_pinyin_tw'
  $p = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match '^patch:\s*(#.*)?$') { $p = $i; break } }
  if ($p -lt 0) {
    if ($Lines -match '^\s*[^#\s]') { throw '看不懂 default.custom.yaml（沒有頂格的 patch:），請手動把 schema_list 加進去，見本目錄的 default.custom.yaml。' }
    return @($Lines | Where-Object { $_ -ne '' }) + 'patch:' + $block
  }
  # patch 區塊到下一個頂格的非註解行為止
  $end = $Lines.Count
  for ($i = $p + 1; $i -lt $Lines.Count; $i++) { if ($Lines[$i] -match '^[^\s#]') { $end = $i; break } }
  $k = -1
  for ($i = $p + 1; $i -lt $end; $i++) {
    if ($Lines[$i] -match '^(\s+)"?schema_list"?\s*:(.*)$') { $k = $i; $ind = $Matches[1]; $rest = ($Matches[2] -replace '#.*$', '').Trim(); break }
  }
  if ($k -lt 0) { return @($Lines | Select-Object -First ($p + 1)) + $block + @($Lines | Select-Object -Skip ($p + 1)) }
  $j = $k + 1
  if ($rest -eq '') {
    # 區塊寫法：舊的清單項目是縮排更深、或同縮排以 - 開頭的行
    $item = '^' + [regex]::Escape($ind) + '(\s+\S|-)'
    while ($j -lt $end -and $Lines[$j] -match $item) { $j++ }
  } elseif ($rest -notmatch '^\[.*\]$') {
    throw '看不懂 default.custom.yaml 的 schema_list 寫法，請手動改成只有 luna_pinyin_tw。'
  }
  $block = $block | ForEach-Object { $ind + $_.Substring(2) }
  return @($Lines | Select-Object -First $k) + $block + @($Lines | Select-Object -Skip $j)
}

$reg = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Rime\Weasel', 'HKLM:\SOFTWARE\Rime\Weasel' -ErrorAction SilentlyContinue |
  Where-Object { $_.WeaselRoot } | Select-Object -First 1
if (-not $reg) { throw '找不到小狼毫。請先從 https://rime.im/ 下載安裝，再跑一次本腳本。' }
$Deployer = Join-Path $reg.WeaselRoot 'WeaselDeployer.exe'

$UserDir = (Get-ItemProperty 'HKCU:\SOFTWARE\Rime\Weasel' -ErrorAction SilentlyContinue).RimeUserDir
if (-not $UserDir) { $UserDir = Join-Path $env:APPDATA 'Rime' }
New-Item -ItemType Directory -Force $UserDir | Out-Null

Write-Host "== 複製到 $UserDir"
$Backup = Join-Path $UserDir ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($f in $Files) {
  $dst = Join-Path $UserDir $f
  # 內容不同的舊檔先備份，不刪
  if ((Test-Path $dst) -and (Get-FileHash $dst).Hash -ne (Get-FileHash (Join-Path $Here $f)).Hash) {
    New-Item -ItemType Directory -Force $Backup | Out-Null
    Copy-Item $dst $Backup
    Write-Host "   舊的 $f 備份到 $Backup"
  }
  Copy-Item (Join-Path $Here $f) $dst -Force
  # Copy-Item 和 ZIP 解壓都會保留舊的修改時間；比上次部署舊的話，小狼毫會當作沒變而跳過部署
  (Get-Item $dst).LastWriteTime = Get-Date
}

# default.custom.yaml 只合併 schema_list，不整個覆蓋
$dst = Join-Path $UserDir 'default.custom.yaml'
if (-not (Test-Path $dst)) {
  Copy-Item (Join-Path $Here 'default.custom.yaml') $dst
  (Get-Item $dst).LastWriteTime = Get-Date
} else {
  $old = [IO.File]::ReadAllText($dst)
  $nl = if ($old -match "`r`n") { "`r`n" } else { "`n" }
  $new = ((Set-SchemaList ($old.TrimEnd("`r", "`n") -split "`r?`n")) -join $nl) + $nl
  if ($new -ne $old) {
    New-Item -ItemType Directory -Force $Backup | Out-Null
    Copy-Item $dst $Backup
    Write-Host "   舊的 default.custom.yaml 備份到 $Backup，只改了 schema_list"
    [IO.File]::WriteAllText($dst, $new, (New-Object Text.UTF8Encoding $false))
  }
}

Write-Host '== 重新部署'
$p = Start-Process $Deployer -ArgumentList '/deploy' -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "部署失敗（exit $($p.ExitCode)），日誌在 $env:TEMP\rime.weasel\" }

Write-Host '== 檢查'
$schema = Join-Path $UserDir 'build\luna_pinyin_tw.schema.yaml'
if (-not (Test-Path $schema)) {
  throw "沒有編出 luna_pinyin_tw 方案。小狼毫可能沒附 luna_pinyin_tw.schema.yaml，見 README.zh-TW.md。"
}
if (-not (Select-String -Path $schema -Pattern '^\s+dictionary: luna_pinyin_ext$' -Quiet)) {
  throw '臺灣正體方案沒有改用 luna_pinyin_ext 詞庫。日誌（' + "$env:TEMP\rime.weasel\" + '）裡沒有 updating workspace 的話，是部署被跳過了'
}
Write-Host '== 完成：臺灣正體方案已改用 luna_pinyin_ext。打 ruan ti、xue ce、lin ci jie bi 試試看。'
