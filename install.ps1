# RamblerPort v1.5 - full installer + verifier
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 [-NoReboot]
#
# What it does, end to end:
#   1. Builds a proper KSU module zip from this repo and installs it via ksud
#   2. Enables ramblerport and zygisk_vector (Vector/LSPosed must stay ON)
#   3. Repairs the mangled pif.json with coherent stock rango values
#   4. Adds the Play Integrity checker to TrickyStore's target.txt
#   5. Reboots, waits for boot, verifies: stock props, XML mount, 2026 feature
#   6. Smoke-tests Pixel Camera, restarts Gboard so it re-reads feature flags
#   7. Launches Play Integrity API Checker, taps "Check", scrapes the verdict
param([switch]$NoReboot, [switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'

$script:Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $script:Adb)) { $script:Adb = (Get-Command adb -ErrorAction Stop).Source }
$Root = $PSScriptRoot

function AdbShell([string]$Cmd) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $script:Adb shell $Cmd 2>&1 | Out-String
    $ErrorActionPreference = $prev
    return $out
}
function SuShell([string]$Cmd) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $script:Adb shell "su -c '$Cmd'" 2>&1 | Out-String
    $ErrorActionPreference = $prev
    return $out
}
function Step([string]$Msg) { Write-Host "`n=== $Msg ===" -ForegroundColor Cyan }

# --- 0. Sanity ---------------------------------------------------------------
Step '0. Device check'
$state = (& $script:Adb get-state) | Out-String
if ($state -notmatch 'device') { throw 'No adb device in "device" state.' }
Write-Host ((AdbShell 'getprop ro.product.device') + (AdbShell 'getprop ro.build.fingerprint'))

# --- 1. Normalize line endings (Android sh chokes on CRLF) -------------------
if ($VerifyOnly) { Step 'VERIFY-ONLY MODE (skipping install/reboot)' } else {
Step '1. Normalize LF'
$textFiles = @('module.prop', 'action.sh', 'service.sh',
               'system\product\etc\sysconfig\pixel_experience_2026.xml')
foreach ($rel in $textFiles) {
    $p = Join-Path $Root $rel
    $raw = [System.IO.File]::ReadAllText($p)
    [System.IO.File]::WriteAllText($p, ($raw -replace "`r`n", "`n"))
    Write-Host "LF: $rel"
}

# --- 2. Build + install module zip -------------------------------------------
Step '2. Install ramblerport via ksud'
# Build the zip with .NET so entry names use '/' (Compress-Archive emits '\'
# which busybox unzip treats as literal filename characters -> broken tree).
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = Join-Path $env:TEMP ("ramblerport_" + [guid]::NewGuid().ToString('N') + '.zip')
$fs = [System.IO.File]::Open($zip, 'Create')
$za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($rel in $textFiles) {
    $entry = $za.CreateEntry(($rel -replace '\\', '/'))
    $w = New-Object System.IO.StreamWriter($entry.Open())
    $w.Write([System.IO.File]::ReadAllText((Join-Path $Root $rel)))
    $w.Dispose()
}
$za.Dispose(); $fs.Dispose()
Write-Host (SuShell 'rm -rf /data/adb/modules/ramblerport')
& $script:Adb push $zip /data/local/tmp/ramblerport.zip | Out-Null
Write-Host (SuShell 'ksud module install /data/local/tmp/ramblerport.zip')
Write-Host (SuShell 'rm -f /data/adb/modules_update/ramblerport/disable /data/adb/modules/ramblerport/disable /data/local/tmp/ramblerport.zip; find /data/adb/modules_update/ramblerport -type f')
Remove-Item $zip -Force

# --- 3. Vector stays ENABLED (user requirement) ------------------------------
Step '3. Enable zygisk_vector'
Write-Host (SuShell 'rm -f /data/adb/modules/zygisk_vector/disable; ls /data/adb/modules/zygisk_vector/disable 2>/dev/null || echo vector-enabled')

# --- 4. Repair pif.json (was: empty codename/model -> integrity fail) --------
Step '4. Fix pif.json'
$pif = @'
{
  "FINGERPRINT": "google/rango/rango:17/CP2A.260805.005/15828068:user/release-keys",
  "MANUFACTURER": "Google",
  "MODEL": "Pixel 10 Pro Fold",
  "SECURITY_PATCH": "2026-08-05",
  "DEVICE_INITIAL_SDK_INT": 36
}
'@
$pif = $pif -replace "`r`n", "`n"
$tmpPif = Join-Path $env:TEMP 'pif.json'
[System.IO.File]::WriteAllText($tmpPif, $pif)
& $script:Adb push $tmpPif /data/local/tmp/pif.json | Out-Null
Remove-Item $tmpPif -Force
Write-Host (SuShell 'cp /data/local/tmp/pif.json /data/adb/modules/playintegrityfix/pif.json; chmod 644 /data/adb/modules/playintegrityfix/pif.json; rm /data/local/tmp/pif.json; cat /data/adb/modules/playintegrityfix/pif.json')

# --- 5. TrickyStore target.txt: include the integrity checker ----------------
Step '5. Fix target.txt'
Write-Host (SuShell 'grep -qx gr.nikolasspyr.integritycheck /data/adb/tricky_store/target.txt || echo gr.nikolasspyr.integritycheck >> /data/adb/tricky_store/target.txt; cat /data/adb/tricky_store/target.txt')

if ($NoReboot) { Write-Host "`n-NoReboot given: reboot manually, then re-run with -VerifyOnly." ; exit 0 }

# --- 6. Reboot and wait -------------------------------------------------------
Step '6. Reboot'
& $script:Adb reboot
Start-Sleep -Seconds 15
& $script:Adb wait-for-device
$deadline = (Get-Date).AddMinutes(4)
do {
    Start-Sleep -Seconds 5
    $booted = (AdbShell 'getprop sys.boot_completed').Trim()
} until ($booted -eq '1' -or (Get-Date) -gt $deadline)
if ($booted -ne '1') { throw 'Device did not finish booting in 4 minutes.' }
Start-Sleep -Seconds 40   # let service.sh (sleep 30) write its boot log
Write-Host 'Boot completed.'
}  # end install block

# --- 6b. Wait for an UNLOCKED screen ------------------------------------------
Step '6b. Waiting for unlocked screen'
# reliable lock state: dumpsys window policy -> KeyguardServiceDelegate "showing=true"
function Test-Locked {
    $kg = AdbShell 'dumpsys window policy | grep showing='
    return ($kg -match 'showing=true')
}
& $script:Adb shell 'input keyevent KEYEVENT_WAKEUP' | Out-Null
& $script:Adb shell 'wm dismiss-keyguard' | Out-Null
if (Test-Locked) {
    Write-Host 'Phone is LOCKED. Please UNFOLD and UNLOCK it now (waiting up to 5 min)...' -ForegroundColor Yellow
    $unlockDeadline = (Get-Date).AddMinutes(5)
    do {
        Start-Sleep -Seconds 5
        & $script:Adb shell 'input keyevent KEYEVENT_WAKEUP' | Out-Null
        & $script:Adb shell 'wm dismiss-keyguard' | Out-Null
    } until (-not (Test-Locked) -or (Get-Date) -gt $unlockDeadline)
}
if (Test-Locked) { throw 'Timed out waiting for unlock. Unfold + unlock the phone and re-run with -VerifyOnly.' }
Write-Host 'Screen unlocked.'

# --- 7. Verify ----------------------------------------------------------------
Step '7. Verify props / XML / feature'
Write-Host (AdbShell 'getprop ro.build.fingerprint; getprop ro.product.device')
Write-Host (SuShell 'ls /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo XML-MISSING')
Write-Host (AdbShell 'pm list features | grep -i pixel_2026 || echo FEATURE-MISSING')
Write-Host (SuShell 'cat /data/local/tmp/ramblerport_boot.log 2>/dev/null')

# --- 8. Camera smoke test ------------------------------------------------------
Step '8. Camera smoke test'
# keep screen on for the whole verification run
$oldTimeout = (AdbShell 'settings get system screen_off_timeout').Trim()
& $script:Adb shell 'settings put system screen_off_timeout 600000' | Out-Null
& $script:Adb shell 'svc power stayon true' | Out-Null
$cam = (AdbShell 'pm list packages | grep -i googlecamera') -replace 'package:', ''
$cam = $cam.Trim()
if ($cam) {
    & $script:Adb shell 'input keyevent KEYEVENT_WAKEUP' | Out-Null
    & $script:Adb shell 'wm dismiss-keyguard' | Out-Null
    Start-Sleep -Seconds 2
    Write-Host (SuShell 'logcat -b crash -c')   # clear so only FRESH crashes count
    & $script:Adb shell "monkey -p $cam -c android.intent.category.LAUNCHER 1" | Out-Null
    Start-Sleep -Seconds 8
    $top = AdbShell 'dumpsys activity activities | grep topResumedActivity'
    Write-Host $top
    if ($top -match 'GoogleCamera|Camera') { Write-Host 'CAMERA: launched OK' -ForegroundColor Green }
    else { Write-Host 'CAMERA: did not come to front - check logcat' -ForegroundColor Red }
    $crash = SuShell 'logcat -b crash -d | tail -30'
    if ($crash -match 'GoogleCamera|cameraserver') { Write-Host "CAMERA CRASH EVIDENCE (fresh):`n$crash" -ForegroundColor Red }
    else { Write-Host 'CAMERA: no fresh crash entries' -ForegroundColor Green }
    & $script:Adb shell 'input keyevent KEYEVENT_HOME' | Out-Null
} else { Write-Host 'GoogleCamera package not found?!' -ForegroundColor Red }

# --- 9. Gboard: re-read flags --------------------------------------------------
Step '9. Restart Gboard'
Write-Host (AdbShell 'am force-stop com.google.android.inputmethod.latin; echo gboard-restarted')

# --- 10. Play Integrity verdict -------------------------------------------------
Step '10. Play Integrity check'
# Proven flow on this device (1080-wide screen): launch -> CHECK FAB -> Show JSON -> scrape verdict.
& $script:Adb shell 'input keyevent KEYEVENT_WAKEUP' | Out-Null
& $script:Adb shell 'wm dismiss-keyguard' | Out-Null
Start-Sleep -Seconds 2
& $script:Adb shell 'am start -n gr.nikolasspyr.integritycheck/.MainActivity' | Out-Null
Start-Sleep -Seconds 4
& $script:Adb shell 'input tap 540 1536' | Out-Null   # CHECK button
Start-Sleep -Seconds 10
& $script:Adb shell 'input tap 914 227' | Out-Null    # "Show JSON response" toolbar icon
Start-Sleep -Seconds 3
& $script:Adb shell 'uiautomator dump /data/local/tmp/uidump2.xml' | Out-Null
$json = (SuShell 'cat /data/local/tmp/uidump2.xml')
$verdicts = [regex]::Matches($json, 'MEETS_[A-Z]+_INTEGRITY|PLAY_RECOGNIZED|LICENSED|UNLICENSED|NO_ISSUES|"[A-Z_]*ERROR[A-Z_]*"') |
            ForEach-Object { $_.Value } | Sort-Object -Unique
if ($verdicts) {
    Write-Host 'PLAY INTEGRITY VERDICT:' -ForegroundColor Yellow
    $verdicts | ForEach-Object { Write-Host "  $_" }
    if ($verdicts -contains 'MEETS_STRONG_INTEGRITY') { Write-Host '  -> STRONG (hard) integrity: PASS' -ForegroundColor Green }
    else { Write-Host '  -> STRONG integrity: FAIL (keybox may be revoked - replace /data/adb/tricky_store/keybox.xml)' -ForegroundColor Red }
} else {
    Write-Host 'No verdict found in UI dump - open Play Integrity API Checker manually.'
}
& $script:Adb shell 'input keyevent KEYEVENT_BACK' | Out-Null
# restore screen timeout
if ($oldTimeout -match '^\d+$') { & $script:Adb shell "settings put system screen_off_timeout $oldTimeout" | Out-Null }
& $script:Adb shell 'svc power stayon false' | Out-Null
Write-Host "`nDone. If FEATURE-MISSING persists, check mountify: su -c 'mountify status' (or its logs)." -ForegroundColor Cyan
