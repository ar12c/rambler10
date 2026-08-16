#!/system/bin/sh
# RamblerPort: "Rambler is gone" triage. READ-ONLY - changes nothing on device.
# Run: su -c 'sh /data/local/tmp/diag_rambler.sh'

GB=com.google.android.inputmethod.latin

echo "===== 1. build / OTA state ====="
echo "fingerprint: $(getprop ro.build.fingerprint)"
echo "patch:       $(getprop ro.build.version.security_patch)"
echo "build date:  $(getprop ro.build.date)"

echo
echo "===== 2. ramblerport module state ====="
ls -la /data/adb/modules/ramblerport/ 2>/dev/null || echo "module dir MISSING"
ls /data/adb/modules/ramblerport/disable /data/adb/modules/ramblerport/remove 2>/dev/null && echo "!! disable/remove marker present"
ls /data/adb/modules_update/ramblerport/ 2>/dev/null

echo
echo "===== 3. 2026 experience flag ====="
ls -l /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo "XML MISSING from /product"
pm list features 2>/dev/null | grep -i pixel_2026 || echo "!! PIXEL_2026_EXPERIENCE not in pm list features"

echo
echo "===== 4. boot log from service.sh ====="
cat /data/local/tmp/ramblerport_boot.log 2>/dev/null || echo "no boot log"

echo
echo "===== 5. Gboard package info ====="
dumpsys package $GB 2>/dev/null | grep -E "versionName|versionCode|lastUpdateTime|firstInstallTime" | head -6

echo
echo "===== 6. rambler strings inside Gboard APKs ====="
for f in $(pm path $GB 2>/dev/null | sed 's/^package://'); do
  hits=$(grep -acoi 'rambler' "$f" 2>/dev/null)
  echo "$f  rambler_hits=$hits"
done

echo
echo "===== 7. rambler flag names (unique, from APK bytes) ====="
for f in $(pm path $GB 2>/dev/null | sed 's/^package://'); do
  grep -aoiE '[a-z_]*rambler[a-z_]*' "$f" 2>/dev/null
done | sort -u | head -40

echo
echo "===== 8. rambler in Gboard on-disk flags/prefs ====="
grep -rin 'rambler' /data/data/$GB/shared_prefs/ 2>/dev/null | head -30
grep -ril 'rambler' /data/data/$GB/files/ 2>/dev/null | head -10

echo
echo "===== 9. ASI / PCC versions (Proactive Assistance hosts) ====="
for p in com.google.android.as com.google.android.as.oss com.google.android.pcs; do
  v=$(dumpsys package $p 2>/dev/null | grep -m1 versionName)
  echo "$p: ${v:-not installed}"
done

echo
echo "===== 10. recent Gboard crash? ====="
logcat -b crash -d 2>/dev/null | grep -i 'inputmethod' | tail -5

echo
echo "== done =="
