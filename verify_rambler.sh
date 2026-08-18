#!/system/bin/sh
# RamblerPort: verify the Rambler unlock end to end.
# v1.6: the authoritative signal is the Reborn hook log ("override applied")
# inside Gboard - the DataStore pb bytes may stay 08 00 because the hook
# rewrites values in memory at read time, AFTER the pb is written from
# phenotype. Run: su -c 'sh /data/local/tmp/verify_rambler.sh'
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb

echo "===== 1. runtime override store ====="
ls -laZ /data/data/$GB/gmsflags_xposed/runtime_overrides.db 2>/dev/null || echo "MISSING - run make_overrides_db.py + apply_overrides.sh"

echo
echo "===== 2. fresh Gboard start + hook install ====="
am force-stop $GB
sleep 1
monkey -p $GB -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 15
L=$(ls -t /data/user/0/$GB/gmsflags_xposed/logs/ 2>/dev/null | head -1)
echo "hook log: $L"
grep -c "override applied" /data/user/0/$GB/gmsflags_xposed/logs/$L 2>/dev/null | sed 's/^/override-applied lines: /'
grep "override applied" /data/user/0/$GB/gmsflags_xposed/logs/$L 2>/dev/null | grep -oE "(enable_agentic_dictation|enable_jetson|enable_jetson_in_toolbar|enable_rambler_al_toolbar|enable_rambler_toolbar_at_cursor_position|show_rambler_dict_settings)=[a-z]+" | sort | uniq -c
grep -qE "no overrides for" /data/user/0/$GB/gmsflags_xposed/logs/$L 2>/dev/null && echo "!! hook found NO overrides - store not readable or empty"

echo
echo "===== 3. pb bytes (informational only - hook overrides in memory) ====="
for key in enable_agentic_dictation enable_jetson enable_rambler_al_toolbar show_rambler_dict_settings; do
  off=$(grep -aob "$key" $PB 2>/dev/null | head -1 | cut -d: -f1)
  if [ -z "$off" ]; then echo "$key: NOT IN PB"; continue; fi
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done

echo
echo "===== 4. device identity (rambler eligibility context) ====="
echo "fingerprint: $(getprop ro.build.fingerprint)"
pm list features 2>/dev/null | grep -i pixel_2026 || echo "PIXEL_2026_EXPERIENCE not registered"
