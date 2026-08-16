#!/system/bin/sh
# Stage phenotype.db (+wal/shm) for PC editing. Stops GMS briefly.
DB=/data/data/com.google.android.gms/databases/phenotype.db
W=/data/local/tmp/phenowork
BK=/data/local/tmp/phenobackup

am force-stop com.google.android.gms
am force-stop com.google.android.gms.unstable
sleep 2

rm -rf $W $BK
mkdir -p $W $BK
cp -p $DB $DB-wal $DB-shm $BK/ 2>/dev/null   # pristine backup, stays on device
cp -p $DB $DB-wal $DB-shm $W/  2>/dev/null   # working copy to pull
chmod 644 $W/* $BK/*
echo "-- original perms --"
ls -l $DB*
echo "-- staged --"
ls -l $W/
