#!/system/bin/sh
# RamblerPort diagnostics action.
# Runs privileged from the KSU-Next manager "Action" button.
OUT=/sdcard/Download/ramblerport_camlog.txt
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb

echo "== RamblerPort v2.0 status =="
echo "model:       $(getprop ro.product.model)   (expect: Pixel 11 Pro Fold)"
echo "device:      $(getprop ro.product.device)  (expect: yogi - Rambler server gate keys off Build.DEVICE)"
echo "name:        $(getprop ro.product.name)  (expect: yogi)"
echo "fingerprint: $(getprop ro.build.fingerprint)  (expect: yogi - rambler needs it)"
echo "vendor fp:   $(getprop ro.vendor.build.fingerprint)  (expect: yogi)"
echo "odm fp:      $(getprop ro.odm.build.fingerprint)  (expect: yogi)"
echo "bootimage fp:$(getprop ro.bootimage.build.fingerprint)  (expect: yogi)"
echo "flavor:      $(getprop ro.build.flavor)  (expect: yogi-user)"
echo "build.product: $(getprop ro.build.product)  (expect: yogi)"
echo "xml mounted: $(ls /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo MISSING)"
echo
if pm list features 2>/dev/null | grep -q "PIXEL_2026_EXPERIENCE"; then
  echo "PIXEL_2026_EXPERIENCE: ACTIVE"
else
  echo "PIXEL_2026_EXPERIENCE: not found (mountify did not stage the module - check module is enabled and has system/ layout)"
fi
GV=$(dumpsys package $GB 2>/dev/null | grep -m1 versionName)
echo "Gboard: ${GV:-not found}"
echo

# Live rambler gate state in Gboard's DataStore (08 01 = on).
echo "-- rambler flags in Gboard DataStore --"
for key in enable_agentic_dictation enable_jetson enable_rambler_al_toolbar show_rambler_dict_settings; do
  off=$(grep -aob "$key" $PB 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$off" ]; then echo "$key: NOT IN PB"; continue; fi
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done
echo "(08 00 = off -> run edit_phenotype.py + pheno_push.sh, then verify_rambler.sh)"
echo

# Play Integrity chain: pif.json must be coherent stock rango; TrickyStore
# keybox attests. The yogi fingerprint lives in system props only.
echo "-- integrity chain --"
echo "boot state:  $(getprop ro.boot.verifiedbootstate)/$(getprop ro.boot.flash.locked)/$(getprop ro.boot.vbmeta.device_state) (expect: green/1/locked)"
PIF=/data/adb/modules/playintegrityfix/pif.json
if grep -q '"MODEL": ""' "$PIF" 2>/dev/null || grep -q 'google//' "$PIF" 2>/dev/null; then
  echo "pif.json:    MANGLED (empty codename/model) - re-run install.ps1 to repair"
else
  echo "pif.json:    $(grep -o 'google/[a-z0-9_]*/[a-z0-9_]*' $PIF 2>/dev/null | head -1)"
fi
if [ -f /data/adb/tricky_store/keybox.xml ]; then
  echo "keybox:      present (tee_status: $(cat /data/adb/tricky_store/tee_status 2>/dev/null))"
else
  echo "keybox:      MISSING - STRONG integrity impossible without one"
fi
grep -q "gr.nikolasspyr.integritycheck" /data/adb/tricky_store/target.txt 2>/dev/null \
  && echo "target.txt:  integrity checker included" \
  || echo "target.txt:  integrity checker NOT included"
echo

# v2.0: camera works under global yogi identity via CamFork isolation
# (Build.* overwritten to rango inside the GoogleCamera process only).
if pm list packages -d 2>/dev/null | grep -q GoogleCamera; then
  echo "GoogleCamera: DISABLED - re-enable it: pm enable com.google.android.GoogleCamera"
else
  echo "GoogleCamera: enabled (ok)"
fi
VCLI_CAM=/data/adb/modules/zygisk_vector/cli
if [ -x "$VCLI_CAM" ]; then
  if "$VCLI_CAM" modules ls 2>/dev/null | grep -q "dev.ramblerport.camfork.*enabled" \
     && "$VCLI_CAM" scope ls dev.ramblerport.camfork 2>/dev/null | grep -q "GoogleCamera"; then
    echo "camfork: enabled + scoped to GoogleCamera (camera isolation active)"
  else
    echo "camfork: NOT ACTIVE - camera will crash! Install camfork.apk, then:"
    echo "  cli modules enable dev.ramblerport.camfork"
    echo "  cli scope add dev.ramblerport.camfork com.google.android.GoogleCamera/0"
  fi
fi

# GCAM anti-tamper: LSPosed/Vector hooks in GoogleCamera trip pairip -> SIGSEGV.
# service.sh removes GCAM from scopes at every boot; this is the manual check.
VCLI=/data/adb/modules/zygisk_vector/cli
if [ -x "$VCLI" ]; then
  for mod in ua.polodarb.gmsflags.reborn com.kieronquinn.app.pcs; do
    if "$VCLI" scope ls "$mod" 2>/dev/null | grep -q "GoogleCamera"; then
      echo "WARNING: $mod hooks GoogleCamera - camera will crash. Fixing:"
      "$VCLI" scope rm "$mod" com.google.android.GoogleCamera/0 && echo "  removed."
    fi
  done
  echo "gcam scopes: clean"
fi

if [ -f /data/adb/modules/Iconify/product/overlay/IconifyComponentAMGC.apk ] \
   || [ -f /data/adb/modules/Iconify/system/product/overlay/IconifyComponentAMGC.apk ]; then
  echo "NOTE: Iconify AMGC overlay present. Remove it if the camera misbehaves."
fi

echo "Now test: (1) camera opens, (2) Gboard voice typing shows Rambler, (3) Play Integrity API Checker reports STRONG."

# Capture camera crash evidence if needed
{
  echo "=== crash buffer ==="
  logcat -b crash -d 2>/dev/null | tail -60
  echo "=== camera logcat ==="
  logcat -d 2>/dev/null | grep -iE "cameraserver|GoogleCamera|edgetpu|pairip" | tail -80
} > "$OUT" 2>&1
echo "log saved: $OUT"
