# RamblerPort: Pixel 11 Pro Fold factory-image fetch + feature-diff pipeline.
# Run any time; with -Poll it waits for the Aug 20 drop.
#
#   powershell -ExecutionPolicy Bypass -File get_pixel11_image.ps1 -Poll
#
# What it does:
#   1. Scrapes https://developers.google.com/android/images for the
#      "Pixel 11 Pro Fold" section -> codename, build id, factory zip URL
#      (this also gives us the real fingerprint fields for pif.json).
#   2. Downloads the factory zip, extracts the nested image-*.zip.
#   3. Uses 7-Zip (23.01+, has EROFS support) to pull /product/etc/sysconfig/*.xml
#      and list /product/app + /product/priv-app from product.img.
#   4. adb-pulls the SAME paths from the connected rango and diffs:
#      -> new sysconfig XMLs  = candidates to add to system/product/etc/sysconfig/
#      -> new priv-apps       = candidates to extract/sideload
# Output: .\pixel11dump\ and a diff report on stdout + pixel11dump\diff_report.txt.
param(
    [switch]$Poll,
    [int]$PollMinutes = 30,
    [string]$OutDir = (Join-Path $PSScriptRoot 'pixel11dump')
)
$ErrorActionPreference = 'Stop'
$script:Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $script:Adb)) { $script:Adb = (Get-Command adb -ErrorAction Stop).Source }
$ImagesUrl = 'https://developers.google.com/android/images'

function Find-Pixel11Fold {
    Write-Host "Fetching $ImagesUrl ..."
    $html = (Invoke-WebRequest -Uri $ImagesUrl -UseBasicParsing).Content
    # Factory rows look like:  <codename>" ... "17" ... link to <codename>-<build>-factory-<sha>.zip
    # Find the Pixel 11 Pro Fold table row, then the codename/link near it.
    $sec = [regex]::Match($html, '(?s)Pixel 11 Pro Fold(.{0,4000})')
    if (-not $sec.Success) { return $null }
    $m = [regex]::Match($sec.Groups[1].Value, 'href="(https://dl\.google\.com/dl/android/aosp/([a-z0-9]+)-([a-z0-9.]+)-factory-([a-f0-9]+)\.zip)"')
    if (-not $m.Success) { return $null }
    return @{
        Url      = $m.Groups[1].Value
        Codename = $m.Groups[2].Value
        Build    = $m.Groups[3].Value
    }
}

# --- 1. locate the image -----------------------------------------------------
$info = Find-Pixel11Fold
while (-not $info) {
    if (-not $Poll) { throw 'Pixel 11 Pro Fold not listed yet. Re-run with -Poll to wait for the drop.' }
    Write-Host "Not posted yet. Sleeping $PollMinutes min... (Ctrl+C to abort)"
    Start-Sleep -Seconds ($PollMinutes * 60)
    $info = Find-Pixel11Fold
}
Write-Host "FOUND: codename=$($info.Codename) build=$($info.Build)"
Write-Host "       $($info.Url)"
Write-Host "`n>>> For pif.json: FINGERPRINT google/$($info.Codename)/$($info.Codename):17/$($info.Build)/<incremental>:user/release-keys"
Write-Host '    (incremental = the number after the build id on the images page; verify against ro.build.fingerprint dumps online)'

# --- 2. download + extract ----------------------------------------------------
New-Item -ItemType Directory -Force $OutDir | Out-Null
$zip = Join-Path $OutDir 'factory.zip'
if (-not (Test-Path $zip)) {
    Write-Host 'Downloading factory image (large)...'
    Invoke-WebRequest -Uri $info.Url -OutFile $zip
}
Expand-Archive -Path $zip -DestinationPath $OutDir -Force
$imgZip = Get-ChildItem $OutDir -Recurse -Filter 'image-*.zip' | Select-Object -First 1
Expand-Archive -Path $imgZip.FullName -DestinationPath (Join-Path $OutDir 'images') -Force

# --- 3. extract product partition contents (needs 7-Zip 23.01+ for EROFS) -----
$7z = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
if (-not $7z) { $7z = 'C:\Program Files\7-Zip\7z.exe' }
if (-not (Test-Path $7z)) { throw '7-Zip not found. Install 23.01+ (EROFS read support) and re-run.' }
$productImg = Get-ChildItem (Join-Path $OutDir 'images') -Filter 'product.img' | Select-Object -First 1
$extDir = Join-Path $OutDir 'product'
& $7z x $productImg.FullName "-o$extDir" 'etc/sysconfig/*' 'app/*' 'priv-app/*' -y | Out-Null
Write-Host "extracted product partition subset to $extDir"

# --- 4. pull same paths from rango and diff -----------------------------------
$devDir = Join-Path $OutDir 'rango_product'
New-Item -ItemType Directory -Force "$devDir\etc\sysconfig" | Out-Null
& $script:Adb pull /product/etc/sysconfig "$devDir\etc\sysconfig" | Out-Null
$devApps = (& $script:Adb shell 'ls /product/app /product/priv-app 2>/dev/null') | Sort-Object
$newApps = (Get-ChildItem "$extDir\app","$extDir\priv-app" -Directory -ErrorAction SilentlyContinue).Name | Sort-Object

$report = Join-Path $OutDir 'diff_report.txt'
"== Pixel 11 Pro Fold ($($info.Codename) $($info.Build)) vs rango ==" | Tee-Object $report
"`n-- sysconfig XMLs on Pixel 11 but NOT on rango (module candidates) --" | Tee-Object -Append $report
$newXml = Get-ChildItem "$extDir\etc\sysconfig\*.xml" -ErrorAction SilentlyContinue
$oldXml = Get-ChildItem "$devDir\etc\sysconfig\*.xml" -ErrorAction SilentlyContinue
Compare-Object ($oldXml.Name) ($newXml.Name) | Where-Object SideIndicator -eq '=>' |
    ForEach-Object { $_.InputObject } | Tee-Object -Append $report
"`n-- product apps on Pixel 11 but NOT on rango (extraction candidates) --" | Tee-Object -Append $report
Compare-Object $devApps $newApps | Where-Object SideIndicator -eq '=>' |
    ForEach-Object { $_.InputObject } | Tee-Object -Append $report
"`nReport: $report"
