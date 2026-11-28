# Isolated test of assets/updater/molaplan-update.ps1 with stand-in programs (stub.cs); never touches a
# real Molaplan install or its settings. Run on Windows:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tool\windows\updater_selftest\run-test.ps1 [-Root C:\somewhere\empty]
# Scenarios: good update, new version crashes (rollback), locked file (rollback), package without the program.
param([string]$Root = (Join-Path $env:TEMP 'molaplan-updtest'))
$ErrorActionPreference = 'Stop'
$root = $Root
New-Item -ItemType Directory -Force $root | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'stub.cs') "$root\stub.cs" -Force
Copy-Item (Join-Path $PSScriptRoot '..\..\..\assets\updater\molaplan-update.ps1') "$root\molaplan-update.ps1" -Force
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$script = Join-Path $root 'molaplan-update.ps1'
if (Test-Path $root\app) { Get-Process molaplan -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$root*" } | Stop-Process -Force }
foreach ($d in 'app','work','staging-good','staging-bad','staging-lock','launches.log') { if (Test-Path "$root\$d") { Remove-Item "$root\$d" -Recurse -Force } }
& $csc /nologo /target:winexe /out:"$root\stub.exe" "$root\stub.cs" | Out-Null

function New-Tree($path, $ver, [switch]$Crash, [string]$extra) {
  New-Item -ItemType Directory -Force "$path\data" | Out-Null
  Copy-Item "$root\stub.exe" "$path\molaplan.exe" -Force
  Set-Content "$path\version.txt" $ver
  Set-Content "$path\flutter_windows.dll" "dll-$ver"
  Set-Content -Path "$path\data\app.so" -Value ("so-$ver-" + ('x' * 2000))
  if ($extra) { Set-Content "$path\$extra" $ver }
  if ($Crash) { Set-Content "$path\crash.txt" 'x' }
}
function Reset-Old {
  if (Test-Path "$root\app") { Remove-Item "$root\app" -Recurse -Force }
  if (Test-Path "$root\work") { Remove-Item "$root\work" -Recurse -Force }
  New-Tree "$root\app" '0.20.24' -extra 'old-only.txt'
  New-Item -ItemType Directory -Force "$root\work" | Out-Null
  Set-Content "$root\work\installing.json" '{"from":"0.20.24","to":"0.20.25"}'
  # user data outside the install folder must survive
  New-Item -ItemType Directory -Force "$root\userdata" | Out-Null
  Set-Content "$root\userdata\settings.json" 'my-settings'
}
function Run-Updater($staging, $extraArgs) {
  $old = Start-Process "$root\app\molaplan.exe" -PassThru
  $argl = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-AppPid',$old.Id,'-AppDir',"$root\app",'-Staging',$staging,'-WorkDir',"$root\work",'-FromVersion','0.20.24','-ToVersion','0.20.25','-StartTimeoutSec','25') + $extraArgs
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process powershell.exe -ArgumentList $argl -PassThru -Wait -WindowStyle Hidden
  "  updater exit=$($p.ExitCode) after $([int]$sw.Elapsed.TotalSeconds)s"
}
function Show-State {
  "  app version: " + (Get-Content "$root\app\version.txt")
  "  files: " + ((Get-ChildItem "$root\app" -Recurse -File | ForEach-Object { $_.FullName.Substring("$root\app\".Length) }) -join ', ')
  "  backup version: " + $(if (Test-Path "$root\work\backup\version.txt") { Get-Content "$root\work\backup\version.txt" } else { '(none)' })
  "  result.json: " + $(if (Test-Path "$root\work\result.json") { (Get-Content "$root\work\result.json" -Raw) -replace '\s+',' ' } else { '(none)' })
  "  launches.log: " + ((Get-Content "$root\launches.log" -ErrorAction SilentlyContinue) -join ' | ')
  "  userdata: " + (Get-Content "$root\userdata\settings.json")
  "  staging left: " + (Test-Path $script:lastStaging)
}
function Stop-Stubs { Get-Process molaplan -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$root*" } | Stop-Process -Force }

"=== 1: good update"
New-Tree "$root\staging-good" '0.20.25' -extra 'new-only.txt'
Reset-Old; $script:lastStaging = "$root\staging-good"
Run-Updater "$root\staging-good" @(); Show-State; Stop-Stubs
"=== 2: new version crashes at start -> rollback"
New-Tree "$root\staging-bad" '0.20.25' -Crash -extra 'new-only.txt'
Remove-Item "$root\launches.log" -ErrorAction SilentlyContinue
Reset-Old; $script:lastStaging = "$root\staging-bad"
Run-Updater "$root\staging-bad" @(); Show-State; Stop-Stubs
"=== 3: a file in the install folder is locked (antivirus) -> retries, then rollback"
New-Tree "$root\staging-lock" '0.20.25' -extra 'new-only.txt'
Remove-Item "$root\launches.log" -ErrorAction SilentlyContinue
Reset-Old; $script:lastStaging = "$root\staging-lock"
$fs = [IO.File]::Open("$root\app\data\app.so", 'Open', 'Read', 'Read')
try { Run-Updater "$root\staging-lock" @() } finally { $fs.Close() }
Show-State; Stop-Stubs
"=== 4: staging without the program -> bad_package, old app restarted"
New-Item -ItemType Directory -Force "$root\staging-empty" | Out-Null; Set-Content "$root\staging-empty\readme.txt" x
Remove-Item "$root\launches.log" -ErrorAction SilentlyContinue
Reset-Old; $script:lastStaging = "$root\staging-empty"
Run-Updater "$root\staging-empty" @(); Show-State; Stop-Stubs
"done"
