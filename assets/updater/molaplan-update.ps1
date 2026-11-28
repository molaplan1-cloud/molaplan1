# Molaplan updater (R700-R719). Started by the app itself, which then exits. ASCII only.
#
# 1. waits for Molaplan to exit
# 2. (asks Windows for administrator rights through UAC if the install folder is not writable)
# 3. copies the current install to a backup, then copies the new, already verified files over it
# 4. starts the new Molaplan and waits for it to report that it started
# 5. if the new version does not start: restores the backup, starts the old version again
#
# The user's settings and data are NOT in the install folder, so they are never touched.
# Everything is logged to update.log in the work folder; the outcome of a failed run goes
# to result.json, which the app shows in plain language the next time it starts.
param(
  [Parameter(Mandatory = $true)][int]$AppPid,
  [Parameter(Mandatory = $true)][string]$AppDir,
  [Parameter(Mandatory = $true)][string]$Staging,
  [Parameter(Mandatory = $true)][string]$WorkDir,
  [string]$ExeName = 'molaplan.exe',
  [string]$FromVersion = '',
  [string]$ToVersion = '',
  [int]$StartTimeoutSec = 40,
  [int]$ExitTimeoutSec = 60,
  [switch]$NoLaunch,
  [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
$AppDir = $AppDir.TrimEnd('\')
$Staging = $Staging.TrimEnd('\')
$WorkDir = $WorkDir.TrimEnd('\')
$Backup = Join-Path $WorkDir 'backup'
$LogFile = Join-Path $WorkDir 'update.log'
$ResultFile = Join-Path $WorkDir 'result.json'
$OkFile = Join-Path $WorkDir 'started-ok.txt'
$ExePath = Join-Path $AppDir $ExeName
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Log([string]$m) {
  try {
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $(if ($Elevated) { 'admin' } else { 'user' }), $m
    [System.IO.File]::AppendAllText($LogFile, $line + "`r`n", $Utf8)
  } catch { }
}

function Write-Result([string]$status, [string]$detail) {
  $o = [ordered]@{ status = $status; from = $FromVersion; to = $ToVersion; detail = $detail; log = $LogFile; at = (Get-Date).ToString('o') }
  [System.IO.File]::WriteAllText($ResultFile, ($o | ConvertTo-Json), $Utf8)
  Log ("result: $status - $detail")
}

function Test-Writable([string]$dir) {
  $probe = Join-Path $dir ('.molaplan-write-test-' + [guid]::NewGuid().ToString('N'))
  try {
    [System.IO.File]::WriteAllText($probe, 'x')
    Remove-Item -LiteralPath $probe -Force
    return $true
  } catch {
    return $false
  }
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-AppProcesses {
  $name = [System.IO.Path]::GetFileNameWithoutExtension($ExeName)
  @(Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object {
      try { $_.Path -and ($_.Path -ieq $ExePath) } catch { $false }
    })
}

# robocopy: exit codes 0-7 are success (files copied / extra files), 8 and up are failures.
# -Force also rewrites files that look identical (same size and time); used for the new files.
function Copy-Tree([string]$from, [string]$to, [switch]$Mirror, [switch]$Force) {
  $mode = if ($Mirror) { '/MIR' } else { '/E' }
  $opts = @($mode, '/R:6', '/W:3', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
  if ($Force) { $opts += '/IS' }
  $out = & robocopy.exe $from $to @opts 2>&1
  $code = $LASTEXITCODE
  Log ("robocopy $from -> $to ($mode) exit $code")
  if ($code -ge 8) {
    $tail = ($out | Select-Object -Last 4) -join ' | '
    throw "COPY_FAILED($code): $tail"
  }
}

function Start-App {
  if ($NoLaunch) { Log 'launch skipped (-NoLaunch)'; return }
  if ((Test-Admin) -and $Elevated) {
    # Start it as the normal user, not with administrator rights.
    Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $ExePath + '"')
  } else {
    Start-Process -FilePath $ExePath -WorkingDirectory $AppDir
  }
  Log "started $ExePath"
}

function Wait-ForStart {
  # True when the new app wrote started-ok.txt (or is still running when the time is up);
  # false when it died before reporting.
  $began = Get-Date
  $seen = $false
  $deadAt = $null
  while (((Get-Date) - $began).TotalSeconds -lt $StartTimeoutSec) {
    if (Test-Path -LiteralPath $OkFile) {
      $v = ''
      try { $v = ([System.IO.File]::ReadAllText($OkFile)).Trim() } catch { }
      if ($v -eq $ToVersion -or $ToVersion -eq '') { Log "app reported it started ($v)"; return $true }
    }
    if ((Get-AppProcesses).Count -gt 0) {
      $seen = $true
      $deadAt = $null
    } elseif ($seen -or (((Get-Date) - $began).TotalSeconds -gt 10)) {
      # It ran and is gone, or it never showed up within 10 s: give it 3 s, then call it dead.
      if (-not $deadAt) { $deadAt = Get-Date }
      elseif (((Get-Date) - $deadAt).TotalSeconds -ge 3) { Log 'the new app exited before it reported a start'; return $false }
    }
    Start-Sleep -Milliseconds 500
  }
  if ((Get-AppProcesses).Count -gt 0) { Log 'no start report, but the app is running; keeping the update'; return $true }
  return $false
}

function Invoke-Rollback([string]$why) {
  Log "rolling back: $why"
  foreach ($p in (Get-AppProcesses)) { try { $p.Kill(); $p.WaitForExit(5000) | Out-Null } catch { } }
  $err = ''
  try {
    Copy-Tree $Backup $AppDir -Mirror
  } catch {
    $err = $_.Exception.Message
    Log "rollback copy failed: $err"
  }
  if ($err -eq '') { Write-Result 'rolled_back' $why } else { Write-Result 'rollback_failed' "$why / $err" }
  Start-App
}

function Invoke-Update {
  Log "update $FromVersion -> $ToVersion; app dir $AppDir; staging $Staging"
  if (-not (Test-Path -LiteralPath (Join-Path $Staging $ExeName))) { Write-Result 'bad_package' "$ExeName is missing from the new files"; Start-App; return }

  if (Test-Path -LiteralPath $OkFile) { Remove-Item -LiteralPath $OkFile -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force -Path $Backup | Out-Null

  try {
    Copy-Tree $AppDir $Backup -Mirror
  } catch {
    Write-Result 'backup_failed' $_.Exception.Message
    Start-App
    return
  }

  try {
    Copy-Tree $Staging $AppDir -Force
  } catch {
    # Locked files (virus scanner, another copy of Molaplan) survived 6 retries; undo what was copied.
    Invoke-Rollback ('copy failed: ' + $_.Exception.Message)
    return
  }

  Remove-Item -LiteralPath $OkFile -Force -ErrorAction SilentlyContinue
  Start-App
  if ($NoLaunch) { Write-Result 'ok' 'files replaced (no launch)'; return }
  if (Wait-ForStart) {
    Log 'update finished'
    Remove-Item -LiteralPath $Staging -Recurse -Force -ErrorAction SilentlyContinue
  } else {
    Invoke-Rollback 'the new version did not start'
  }
}

# ---------------------------------------------------------------- main
try {
  New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
  if (Test-Path -LiteralPath $ResultFile) { Remove-Item -LiteralPath $ResultFile -Force }

  if (-not $Elevated) {
    Log "updater started (pid $PID), waiting for Molaplan pid $AppPid to exit"
    $deadline = (Get-Date).AddSeconds($ExitTimeoutSec)
    while ((Get-Date) -lt $deadline) {
      $alive = $false
      try { $alive = [bool](Get-Process -Id $AppPid -ErrorAction SilentlyContinue) } catch { }
      if (-not $alive -and (Get-AppProcesses).Count -eq 0) { break }
      Start-Sleep -Milliseconds 400
    }
    if ((Get-AppProcesses).Count -gt 0) {
      Write-Result 'app_still_running' 'Molaplan did not close in time'
      return
    }
    Start-Sleep -Milliseconds 400
  }

  if (-not (Test-Writable $AppDir)) {
    if ($Elevated) {
      Write-Result 'not_writable' "no write access to $AppDir even with administrator rights"
      Start-App
      return
    }
    Log 'install folder is not writable; asking Windows for administrator rights'
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $PSCommandPath + '"'),
      '-AppPid', [string]$AppPid, '-AppDir', ('"' + $AppDir + '"'), '-Staging', ('"' + $Staging + '"'), '-WorkDir', ('"' + $WorkDir + '"'),
      '-ExeName', $ExeName, '-FromVersion', $FromVersion, '-ToVersion', $ToVersion,
      '-StartTimeoutSec', [string]$StartTimeoutSec, '-ExitTimeoutSec', [string]$ExitTimeoutSec, '-Elevated')
    if ($NoLaunch) { $argList += '-NoLaunch' }
    try {
      $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -PassThru -Wait
      Log "elevated updater exited with $($p.ExitCode)"
    } catch {
      Write-Result 'elevation_declined' $_.Exception.Message
      Start-App
    }
    return
  }

  Invoke-Update
} catch {
  Write-Result 'failed' ($_.Exception.Message)
  try { Start-App } catch { }
}
