#!/system/bin/sh
# RamblerPort diagnostics action.
# Runs privileged from the KSU-Next manager "Action" button.
OUT=/sdcard/Download/ramblerport_camlog.txt

echo "== RamblerPort v1.5 status =="
echo "model:       $(getprop ro.product.model)   (expect: Pixel 10 Pro Fold)"
echo "device:      $(getprop ro.product.device)  (expect: rango)"
echo "fingerprint: $(getprop ro.build.fingerprint)  (expect: rango/stock - camera safe)"
echo "xml mounted: $(ls /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo MISSING)"
echo
if pm list features 2>/dev/null | grep -q "PIXEL_2026_EXPERIENCE"; then
  echo "PIXEL_2026_EXPERIENCE: ACTIVE"
else
  echo "PIXEL_2026_EXPERIENCE: not found"
fi
GV=$(dumpsys package com.google.android.inputmethod.latin 2>/dev/null | grep -m1 versionName)
echo "Gboard: ${GV:-not found}"
echo

# Play Integrity chain: stock fingerprint must match what TrickyStore attests.
echo "-- integrity chain --"
echo "boot state:  $(getprop ro.boot.verifiedbootstate)/$(getprop ro.boot.flash.locked)/$(getprop ro.boot.vbmeta.device_state) (expect: green/1/locked)"
if [ -f /data/adb/tricky_store/keybox.xml ]; then
  echo "keybox:      present (tee_status: $(cat /data/adb/tricky_store/tee_status 2>/dev/null))"
else
  echo "keybox:      MISSING - STRONG integrity impossible without one"
fi
grep -q "gr.nikolasspyr.integritycheck" /data/adb/tricky_store/target.txt 2>/dev/null \
  && echo "target.txt:  integrity checker included" \
  || echo "target.txt:  integrity checker NOT included"
echo

# The Iconify Gcam overlay breaks Pixel Camera under any spoof - with the
# stock fingerprint this is informational only.
if [ -f /data/adb/modules/Iconify/product/overlay/IconifyComponentAMGC.apk ]; then
  echo "NOTE: Iconify AMGC overlay present. Remove it if the camera misbehaves."
fi

# Any LSPosed hook into GoogleCamera trips its pairip anti-tamper -> SIGSEGV
# on launch. GoogleCamera must stay OUT of every Vector module scope.
VCLI=/data/adb/modules/zygisk_vector/cli
if [ -x "$VCLI" ]; then
  for mod in ua.polodarb.gmsflags.reborn com.kieronquinn.app.pcs; do
    if "$VCLI" scope ls "$mod" 2>/dev/null | grep -q "GoogleCamera"; then
      echo "WARNING: $mod hooks GoogleCamera - camera will crash. Run:"
      echo "  $VCLI scope rm $mod com.google.android.GoogleCamera/0"
    fi
  done
fi

echo "Now test: (1) camera opens, (2) Gboard voice typing shows Rambler, (3) Play Integrity API Checker reports STRONG."

# Capture camera crash evidence if needed
{
  echo "=== crash buffer ==="
  logcat -b crash -d 2>/dev/null | tail -60
  echo "=== camera logcat ==="
  logcat -d 2>/dev/null | grep -iE "cameraserver|GoogleCamera|edgetpu" | tail -80
} > "$OUT" 2>&1
echo "log saved: $OUT"
