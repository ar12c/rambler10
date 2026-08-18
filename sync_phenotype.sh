#!/system/bin/sh
# RamblerPort: observe whether the Phenotype server serves rambler flags under
# the current (yogi) identity, and confirm the local flag_overrides rows exist.
#
# v1.6 reality check: on this device the server has NEVER served rambler flags
# (param_partitions has zero rambler entries, even under the yogi fingerprint).
# The unlock therefore comes from the LOCAL flag_overrides rows written by
# edit_phenotype.py (same mechanism as root GMS Flags) - this script just
# verifies they are present and active.
# Run: su -c 'sh /data/local/tmp/sync_phenotype.sh'
DB=/data/data/com.google.android.gms/databases/phenotype.db

echo "== flag_overrides rows for Gboard (the actual unlock mechanism) =="
# table is binary sqlite; grep gives a quick presence check per flag name.
for key in enable_agentic_dictation enable_jetson enable_jetson_in_toolbar enable_rambler_al_toolbar enable_rambler_toolbar_at_cursor_position show_rambler_dict_settings; do
  if grep -aqo "$key" $DB 2>/dev/null; then
    echo "  $key: present in phenotype.db"
  else
    echo "  $key: MISSING - run edit_phenotype.py + pheno_push.sh"
  fi
done

echo
echo "== stale pre-v1.6 override names (should be gone) =="
for key in rambler_al_toolbar rambler_dict_settings rambler_toolbar_at_cursor_position; do
  # exact match only: skip hits that are substrings of enable_/show_ names
  if grep -aoE "[^a-z_]$key" $DB 2>/dev/null | grep -q .; then
    echo "  $key: STALE ROW STILL PRESENT (harmless, but edit_phenotype.py should have deleted it)"
  else
    echo "  $key: clean"
  fi
done

echo
echo "== server-served rambler flags in committed config (expected: none) =="
grep -aoiE '[a-z_]*rambler[a-z_]*' $DB 2>/dev/null | sort -u | head -30
