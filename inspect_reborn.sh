#!/system/bin/sh
# Inspect GMS Flags Reborn storage layout. READ-ONLY.
# v1.6 NOTE: the RUNTIME OVERRIDE STORE is NOT in Reborn's dir. The Xposed hook
# inside each target app reads <target_data>/gmsflags_xposed/runtime_overrides.db
# (table RuntimeFlagOverrides: packageName, name, flagType, value). Build it with
# make_overrides_db.py and install it with apply_overrides.sh. The paths below
# are just Reborn's own flag-cache dirs, kept for reference.
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
