# 在 Windows 上裝好小狼毫（Weasel）的臺灣正體拼音：複製設定與詞庫、重新部署、檢查方案有沒有接上詞庫。
# 小狼毫要先裝好（https://rime.im/）。簡體請用 Windows 內建的微軟拼音，本腳本不處理。
# 用法（PowerShell，在本目錄執行）: .\install.ps1
$ErrorActionPreference = 'Stop'

$Here = $PSScriptRoot
$Files = 'luna_pinyin_ext.dict.yaml', 'luna_pinyin_extra.dict.yaml', 'luna_pinyin_tw.custom.yaml', 'default.custom.yaml'

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
}

Write-Host '== 重新部署'
$p = Start-Process $Deployer -ArgumentList '/deploy' -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "部署失敗（exit $($p.ExitCode)），日誌在 $env:TEMP\rime.weasel\" }

Write-Host '== 檢查'
$schema = Join-Path $UserDir 'build\luna_pinyin_tw.schema.yaml'
if (-not (Test-Path $schema)) {
  throw "沒有編出 luna_pinyin_tw 方案。小狼毫可能沒附 luna_pinyin_tw.schema.yaml，見 README。"
}
if (-not (Select-String -Path $schema -Pattern '^\s+dictionary: luna_pinyin_ext$' -Quiet)) {
  throw '臺灣正體方案沒有改用 luna_pinyin_ext 詞庫，日誌在 ' + "$env:TEMP\rime.weasel\"
}
Write-Host '== 完成：臺灣正體方案已改用 luna_pinyin_ext。打 ruan ti、xue ce、lin ci jie bi 試試看。'
