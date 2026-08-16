#!/system/bin/sh
# Install edited phenotype.db back into GMS, then verify Gboard re-sync keeps rambler=1.
DB=/data/data/com.google.android.gms/databases/phenotype.db
W=/data/local/tmp/phenowork

echo "== stop GMS (again, in case it relaunched) =="
am force-stop com.google.android.gms
am force-stop com.google.android.gms.unstable
sleep 2

echo "== swap in edited db =="
rm -f $DB-wal $DB-shm                      # stale after stop; edited db is checkpointed
cp $W/phenotype.db $DB
chown u0_a335:u0_a335 $DB
chmod 660 $DB
restorecon $DB
ls -l $DB*

echo "== restart Gboard so it re-syncs flags from the provider =="
am force-stop com.google.android.inputmethod.latin
sleep 1
am start -n com.google.android.inputmethod.latin/com.google.android.libraries.inputmethod.launcher.LauncherActivity >/dev/null 2>&1 \
  || monkey -p com.google.android.inputmethod.latin 1 >/dev/null 2>&1
echo "waiting 30s for Gboard <-> phenotype sync..."
sleep 30

echo "== verify: rambler gate values in Gboard DataStore after re-sync =="
PB=/data/data/com.google.android.inputmethod.latin/files/datastore/flags_jetpack_data_store.pb
for key in rambler_al_toolbar rambler_dict_settings rambler_toolbar_at_cursor_position; do
  off=$(grep -aob "$key" $PB | head -1 | cut -d: -f1)
  [ -z "$off" ] && { echo "$key: NOT IN PB"; continue; }
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done
echo "08 01 = override held through a full provider re-sync. 08 00 = override rejected."
