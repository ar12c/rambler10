#!/system/bin/sh
# Locate GMS Flags Reborn's override store + check for sqlite3. READ-ONLY.
echo "== sqlite3 available? =="
command -v sqlite3 || echo "no sqlite3 in PATH"
ls /data/adb/ksu/bin/ 2>/dev/null | head
ls /data/adb/magisk/busybox 2>/dev/null

echo
echo "== Reborn/Vector storage locations =="
find /data/adb -maxdepth 4 \( -iname '*reborn*' -o -iname '*gmsflag*' -o -iname '*vector*' \) 2>/dev/null | head -20
echo "-- vector module dir --"
ls -la /data/adb/modules/zygisk_vector/ 2>/dev/null | head -20

echo
echo "== LSPosed/Vector manager data (RemotePreferences live here) =="
ls -d /data/adb/lspd /data/adb/vector /data/adb/modules/zygisk_vector 2>/dev/null
find /data/adb/lspd /data/adb/vector -maxdepth 3 2>/dev/null | head -40
echo "-- manager packages in /data/data --"
ls -d /data/data/*lsposed* /data/data/*vector* /data/data/*reborn* 2>/dev/null

echo
echo "== any file mentioning our gboard phenotype package =="
grep -rls 'inputmethod.latin#com.google.android.inputmethod.latin' /data/adb 2>/dev/null | head -10

echo
echo "== phenotype.db schema (tables) =="
grep -aoE 'CREATE TABLE [A-Za-z_]+' /data/data/com.google.android.gms/databases/phenotype.db 2>/dev/null | sort -u
