#!/system/bin/sh
# RamblerPort: after switching pif.json to the Pixel 11 Pro Fold identity,
# restart GMS so phenotype re-checks in, then poll for rambler flags returning.
# If they appear, the server accepts the spoof and the pb patch becomes a
# belt-and-suspenders fallback. Run: su -c 'sh /data/local/tmp/sync_phenotype.sh'
GB=com.google.android.inputmethod.latin
DB=/data/data/com.google.android.gms/databases/phenotype.db

echo "before: phenotype.db rambler hits = $(grep -acoi rambler $DB 2>/dev/null)"

am force-stop com.google.android.gms
am force-stop com.google.android.gms.unstable
am force-stop $GB
echo "gms restarted; polling for rambler flags (10 x 30s)..."
echo "(tip: toggling airplane mode or hitting 'sync' in GMS Flags Reborn speeds up checkin)"

i=1
while [ $i -le 10 ]; do
  sleep 30
  hits=$(grep -acoi rambler $DB 2>/dev/null)
  echo "poll $i: rambler hits = ${hits:-0}"
  if [ "${hits:-0}" -gt 0 ]; then
    echo "SPOOF ACCEPTED - server is serving rambler flags again:"
    grep -aoiE '[a-z_]*rambler[a-z_]*' $DB 2>/dev/null | sort -u | head -30
    echo "now force-stop Gboard once more and test voice typing."
    exit 0
  fi
  i=$((i+1))
done
echo "no rambler flags after 5 min. Either the checkin has not happened yet,"
echo "PIF is not covering the checkin process, or the server gates on more than"
echo "the reported identity. Rerun later or check PIF scope."
