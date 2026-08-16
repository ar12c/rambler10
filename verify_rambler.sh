#!/system/bin/sh
# Verify Reborn hook now feeds rambler=true into Gboard across a full flag re-sync.
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb

am force-stop $GB
sleep 1
monkey -p $GB -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "waiting 30s for Gboard to re-sync flags through the hooked provider..."
sleep 30

for key in rambler_al_toolbar rambler_dict_settings rambler_toolbar_at_cursor_position; do
  off=$(grep -aob "$key" $PB 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$off" ]; then echo "$key: NOT IN PB"; continue; fi
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done
echo "08 01 = Reborn override survived a full re-sync (permanent). 08 00 = still wiped."
