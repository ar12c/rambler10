#!/system/bin/sh
# RamblerPort: install runtime_overrides.db into Gboard's gmsflags_xposed dir.
# The Reborn Xposed hook reads it in-process and rewrites the rambler flags at
# read time (survives phenotype re-syncs, pb rewrites, and Gboard updates that
# keep the same flag names). Run on DEVICE as root:
#   su -c 'sh /data/local/tmp/apply_overrides.sh'
# Expects rambler_overrides.db next to this script in /data/local/tmp.
GB=com.google.android.inputmethod.latin
SRC=/data/local/tmp/rambler_overrides.db
DST=/data/data/$GB/gmsflags_xposed/runtime_overrides.db

if [ ! -f "$SRC" ]; then echo "missing $SRC - run make_overrides_db.py and adb push it"; exit 1; fi
if [ ! -d /data/data/$GB ]; then echo "Gboard not installed?!"; exit 1; fi

mkdir -p /data/data/$GB/gmsflags_xposed
cp "$SRC" "$DST"

# owner + perms + SELinux: match Gboard's own data files
OWNER=$(stat -c '%U:%G' /data/data/$GB/files 2>/dev/null || ls -ld /data/data/$GB/files | awk '{print $3":"$4}')
chown "$OWNER" /data/data/$GB/gmsflags_xposed "$DST" 2>/dev/null
chmod 700 /data/data/$GB/gmsflags_xposed
chmod 660 "$DST"
restorecon /data/data/$GB/gmsflags_xposed "$DST" 2>/dev/null
ls -laZ "$DST"

# keep Reborn's own dir clean of stale copies (hook never reads those)
rm -f /data/data/ua.polodarb.gmsflags.reborn/databases/runtime_overrides.db 2>/dev/null

echo "== restart Gboard so the hook installs with the new store =="
am force-stop $GB
sleep 1
monkey -p $GB -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 10

L=$(ls -t /data/user/0/$GB/gmsflags_xposed/logs/ 2>/dev/null | head -1)
echo "== hook log ($L) =="
grep -E "override (applied|hook installed)|no overrides|not readable" /data/user/0/$GB/gmsflags_xposed/logs/$L 2>/dev/null | sort | uniq -c | sort -rn | head -15
echo
echo "If you see 'override applied: ... enable_agentic_dictation=true', Rambler's"
echo "master switch is live. Open any text field -> voice typing -> Rambler strip."
