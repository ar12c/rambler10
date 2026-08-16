#!/system/bin/sh
# Automated Play Integrity verdict capture for gr.nikolasspyr.integritycheck
am start -n gr.nikolasspyr.integritycheck/.MainActivity >/dev/null 2>&1
sleep 4
# tap CHECK (center of the check FAB/button measured from UI dump)
input tap 540 1536
sleep 10
# tap "Show JSON response" toolbar icon
input tap 914 227
sleep 3
uiautomator dump /data/local/tmp/uidump2.xml >/dev/null 2>&1
echo "--- dump2 text fields ---"
grep -o 'text="[^"]*"' /data/local/tmp/uidump2.xml | sort -u | head -60
