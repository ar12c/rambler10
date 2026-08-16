#!/system/bin/sh
# RamblerPort triage #2: read the actual rambler flag values + model packs. READ-ONLY.
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb

echo "===== A. Gboard flag files present ====="
ls -la /data/data/$GB/shared_prefs/ 2>/dev/null | grep -i flag
ls -l $PB 2>/dev/null

echo
echo "===== B. rambler keys + raw values in DataStore pb ====="
# boolean proto values are a varint 00/01 a few bytes after the key string.
for off in $(grep -aob 'rambler' $PB 2>/dev/null | cut -d: -f1 | head -25); do
  echo "--- offset $off ---"
  dd if=$PB bs=1 skip=$off count=72 2>/dev/null | xxd
done

echo
echo "===== C. datadownload packs (rambler model/dictionary delivery) ====="
ls -la /data/data/$GB/files/datadownload/shared/public/ 2>/dev/null
echo "-- which packs mention rambler --"
grep -rlsi 'rambler' /data/data/$GB/files/datadownload/ 2>/dev/null

echo
echo "===== D. does the Phenotype server package still serve rambler flags? ====="
for db in /data/data/com.google.android.gms/databases/phenotype.db; do
  if [ -f "$db" ]; then
    echo "$db: $(grep -acoi rambler "$db" 2>/dev/null) rambler hits"
    grep -aoiE '[a-z_]*rambler[a-z_]*' "$db" 2>/dev/null | sort -u | head -30
  else
    echo "$db missing"
  fi
done

echo
echo "===== E. existing overrides (GMS Flags Reborn / flag_override.xml) ====="
cat /data/data/$GB/shared_prefs/flag_override.xml 2>/dev/null | grep -i rambler
grep -ri 'rambler' /data/data/ua.polodarb.gmsflags.reborn/ 2>/dev/null | head -20

echo
echo "== done =="
