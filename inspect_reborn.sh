#!/system/bin/sh
# Inspect GMS Flags Reborn storage layout. READ-ONLY.
R=/data/data/ua.polodarb.gmsflags.reborn

echo "== files/phenotype tree =="
ls -laR $R/files/phenotype/ 2>/dev/null
echo
echo "== files/phenotype_storage_info tree =="
ls -laR $R/files/phenotype_storage_info/ 2>/dev/null
echo
echo "== contents of any files therein =="
for f in $(find $R/files/phenotype $R/files/phenotype_storage_info -type f 2>/dev/null); do
  echo "--- $f"
  cat "$f" 2>/dev/null | head -25
  echo
done
echo "== datastore prefs (non-firebase) =="
for f in $R/files/datastore/*.preferences_pb; do
  echo "--- $f"
  xxd "$f" 2>/dev/null | head -20
done
