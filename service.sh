#!/system/bin/sh
# RamblerPort late-start service.
#  1. Boot-time verification log (diagnostics).
#  2. GCAM anti-tamper guard: any LSPosed/Vector hook inside the GoogleCamera
#     process trips its pairip anti-tamper -> SIGSEGV on launch. Remove
#     GoogleCamera from every known Vector module scope at every boot.
#     v2.1: includes our own CamFork - v2.0's "pairip-safe Build rewrite" claim
#     was WRONG (tombstones: SEGV_ACCERR in libpairipcore.so). CamFork is
#     retired; GCAM 11.0.073+ knows yogi natively, no in-process spoof needed.
#  3. Rambler override self-heal: make sure the Reborn runtime override store
#     exists in Gboard's gmsflags_xposed dir (a Gboard update or data clear
#     would otherwise silently kill Rambler).
LOG=/data/local/tmp/ramblerport_boot.log
VCLI=/data/adb/modules/zygisk_vector/cli
GCAM=com.google.android.GoogleCamera
GB=com.google.android.inputmethod.latin
MODDIR=${0%/*}
STORE_SRC=$MODDIR/rambler_overrides.db
STORE_DST=/data/data/$GB/gmsflags_xposed/runtime_overrides.db

sleep 30
{
  date
  echo "model=$(getprop ro.product.model)"
  echo "device=$(getprop ro.product.device)"
  echo "fingerprint=$(getprop ro.build.fingerprint)"
  echo "vendor_fp=$(getprop ro.vendor.build.fingerprint)"
  echo "odm_fp=$(getprop ro.odm.build.fingerprint)"
  echo "bootimage_fp=$(getprop ro.bootimage.build.fingerprint)"
  echo "flavor=$(getprop ro.build.flavor)"
  echo "build_product=$(getprop ro.build.product)"
  echo "xml=$(ls /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo MISSING)"
  pm list features 2>/dev/null | grep -i "pixel_2026"
} > $LOG 2>&1

# --- GCAM pairip guard -------------------------------------------------------
# The Vector daemon may still be starting; retry for ~2 minutes.
i=0
while [ $i -lt 12 ]; do
  [ -x "$VCLI" ] && "$VCLI" scope ls >/dev/null 2>&1 && break
  sleep 10
  i=$((i + 1))
done

if [ -x "$VCLI" ]; then
  for mod in ua.polodarb.gmsflags.reborn com.kieronquinn.app.pcs dev.ramblerport.camfork; do
    if "$VCLI" scope ls "$mod" 2>/dev/null | grep -q "$GCAM"; then
      "$VCLI" scope rm "$mod" "$GCAM/0" 2>&1
      echo "gcam-guard: removed $GCAM from $mod scope" >> $LOG
    else
      echo "gcam-guard: $mod does not hook $GCAM (ok)" >> $LOG
    fi
  done
else
  echo "gcam-guard: vector cli not found - skipped" >> $LOG
fi

# Iconify's AMGC overlay breaks Pixel Camera under any spoof.
if [ -f /data/adb/modules/Iconify/product/overlay/IconifyComponentAMGC.apk ] \
   || [ -f /data/adb/modules/Iconify/system/product/overlay/IconifyComponentAMGC.apk ]; then
  echo "gcam-guard: WARNING Iconify AMGC overlay present - remove it if the camera misbehaves" >> $LOG
fi

# --- Rambler override self-heal ----------------------------------------------
# /data/data/<app> is credential-encrypted: not visible until first unlock.
# Wait (condition-based, up to ~10 min) for CE storage to come online.
i=0
while [ $i -lt 60 ]; do
  [ -d /data/data/$GB/files ] && break
  sleep 10
  i=$((i + 1))
done

if [ -f "$STORE_SRC" ] && [ -d /data/data/$GB/files ]; then
  if [ ! -f "$STORE_DST" ]; then
    mkdir -p /data/data/$GB/gmsflags_xposed
    cp "$STORE_SRC" "$STORE_DST"
    OWNER=$(ls -ld /data/data/$GB/files | awk '{print $3":"$4}')
    chown "$OWNER" /data/data/$GB/gmsflags_xposed "$STORE_DST" 2>/dev/null
    chmod 700 /data/data/$GB/gmsflags_xposed
    chmod 660 "$STORE_DST"
    restorecon /data/data/$GB/gmsflags_xposed "$STORE_DST" 2>/dev/null
    echo "rambler-heal: installed runtime_overrides.db (was missing)" >> $LOG
  else
    echo "rambler-heal: runtime_overrides.db present (ok)" >> $LOG
  fi
else
  echo "rambler-heal: skipped (src missing or CE storage locked)" >> $LOG
fi
