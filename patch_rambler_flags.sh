#!/system/bin/sh
# RamblerPort: flip rambler gates 00->01 in Gboard's Jetpack DataStore flag cache.
# Safe to re-run: verifies proto framing (12 04 0a 02 08) before every write,
# in-place edit (same inode, owner, SELinux label), full backup first.
#
# v1.6: Gboard 18.x flag names. The MASTER SWITCH is enable_agentic_dictation -
# without it Gboard logs "Agentic Dictation is disabled, not activating" and
# none of the UI flags matter. NOTE: this pb is rewritten from phenotype on
# every sync - for permanence use edit_phenotype.py + pheno_push.sh instead.
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
  # exact key match: the byte before the key must not be [a-z_] so we don't
  # land on a substring of a longer name (e.g. filter_rambler_...).
  off=$(grep -aob "$key" $PB | while read -r line; do
    o=${line%%:*}
    prev=$(dd if=$PB bs=1 skip=$((o - 1)) count=1 2>/dev/null | xxd -p | tr -d ' \n')
    case "$prev" in
      6?|5f) continue ;;  # a-z or underscore -> substring of a longer key
    esac
    echo "$o"; break
  done)
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
set_flag enable_agentic_dictation
set_flag enable_jetson
set_flag enable_jetson_in_toolbar
set_flag enable_rambler_al_toolbar
set_flag enable_rambler_toolbar_at_cursor_position
set_flag show_rambler_dict_settings

echo
echo "== verify (expect 08 01 on all gates) =="
for key in enable_agentic_dictation enable_jetson enable_jetson_in_toolbar enable_rambler_al_toolbar enable_rambler_toolbar_at_cursor_position show_rambler_dict_settings; do
  off=$(grep -aob "$key" $PB | head -1 | cut -d: -f1)
  [ -z "$off" ] && continue
  klen=$(printf %s "$key" | wc -c)
  dd if=$PB bs=1 skip=$((off + klen)) count=6 2>/dev/null | xxd | sed "s/^/$key: /"
done

echo
echo "== done. Open any text field -> voice typing -> look for the Rambler waveform strip. =="
