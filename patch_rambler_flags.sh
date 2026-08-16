#!/system/bin/sh
# RamblerPort: flip rambler gates 00->01 in Gboard's Jetpack DataStore flag cache.
# Safe to re-run: verifies proto framing (12 04 0a 02 08) before every write,
# in-place edit (same inode, owner, SELinux label), full backup first.
GB=com.google.android.inputmethod.latin
PB=/data/data/$GB/files/datastore/flags_jetpack_data_store.pb
BK=/data/local/tmp/flags_jetpack_data_store.pb.bak

echo "== stop Gboard (prevent it rewriting the pb while we patch) =="
am force-stop $GB
sleep 1

echo "== backup =="
cp -p $PB $BK && chmod 644 $BK && ls -l $BK

set_flag() {
  key=$1
  off=$(grep -aob "$key" $PB | head -1 | cut -d: -f1)
  if [ -z "$off" ]; then echo "$key: NOT FOUND in pb"; return; fi
  klen=$(printf %s "$key" | wc -c)
  vend=$((off + klen))
  magic=$(dd if=$PB bs=1 skip=$vend count=5 2>/dev/null | xxd -p | tr -d '\n')
  if [ "$magic" != "12040a0208" ]; then
    echo "$key: proto framing mismatch at $vend ($magic) - SKIP"
    return
  fi
  voff=$((vend + 5))
  cur=$(dd if=$PB bs=1 skip=$voff count=1 2>/dev/null | xxd -p | tr -d '\n ')
  printf '\x01' | dd of=$PB bs=1 seek=$voff count=1 conv=notrunc 2>/dev/null
  new=$(dd if=$PB bs=1 skip=$voff count=1 2>/dev/null | xxd -p | tr -d '\n ')
  echo "$key: @$off value $cur -> $new"
}

echo "== patch =="
set_flag rambler_al_toolbar
set_flag rambler_dict_settings
set_flag rambler_toolbar_at_cursor_position

echo
echo "== verify (expect 08 01 on the three gates) =="
for key in rambler_al_toolbar rambler_dict_settings rambler_toolbar_at_cursor_position rambler_contributed_input_view_session; do
  off=$(grep -aob "$key" $PB | head -1 | cut -d: -f1)
  [ -z "$off" ] && continue
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done

echo
echo "== done. Open any text field -> voice typing -> look for the Rambler waveform strip. =="
