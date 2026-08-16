#!/system/bin/sh
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb

echo "== ALL rambler-ish keys in Gboard DataStore with values =="
for off in $(grep -aob 'rambler' $PB 2>/dev/null | cut -d: -f1); do
  klen=0
  # find key length: scan forward until the 12 04 0a 02 08 marker
  dd if=$PB bs=1 skip=$off count=80 2>/dev/null | xxd | head -2
  echo '---'
done

echo
echo "== hook diagnostics: did Reborn apply overrides inside Gboard? =="
HD=/data/user/0/$GB/gmsflags_xposed/hook_diagnostics.db
cp -p $HD /data/local/tmp/hd.db 2>/dev/null && chmod 644 /data/local/tmp/hd.db
ls -la /data/user/0/$GB/gmsflags_xposed/logs/ 2>/dev/null
for f in /data/user/0/$GB/gmsflags_xposed/logs/*; do
  echo "--- $f"
  tail -30 "$f" 2>/dev/null
done
