#!/system/bin/sh
# RamblerPort status check + camera crash capture
# Runs privileged from the KSU-Next manager "Action" button.
OUT=/sdcard/Download/ramblerport_camlog.txt

echo "== RamblerPort v1.2 status =="
echo "model:       $(getprop ro.product.model)   (expect real: Pixel 10 Pro Fold)"
echo "device:      $(getprop ro.product.device)  (expect real: rango)"
echo "fingerprint: $(getprop ro.build.fingerprint)"
echo
if pm list features 2>/dev/null | grep -q "PIXEL_2026_EXPERIENCE"; then
  echo "PIXEL_2026_EXPERIENCE: ACTIVE"
else
  echo "PIXEL_2026_EXPERIENCE: NOT VISIBLE (module not applied? reboot needed?)"
fi
echo
GV=$(dumpsys package com.google.android.inputmethod.latin 2>/dev/null | grep -m1 versionName)
echo "Gboard: ${GV:-not found}"
echo
echo "Now test: (1) camera opens, (2) Gboard voice typing shows Rambler."

# Capture camera crash evidence if needed
{
  echo "=== crash buffer ==="
  logcat -d -b crash -t 200 2>/dev/null
  echo
  echo "=== camera/fatal lines (main) ==="
  logcat -d -b main 2>/dev/null | grep -iE 'FATAL EXCEPTION|AndroidRuntime|GoogleCamera|cameraserver|CameraService|libgcam' | tail -100
} > "$OUT" 2>&1
