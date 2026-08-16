#!/system/bin/sh
# RamblerPort boot-time verification log (diagnostics only)
sleep 30
{
  date
  echo "model=$(getprop ro.product.model)"
  echo "device=$(getprop ro.product.device)"
  echo "fingerprint=$(getprop ro.build.fingerprint)"
  pm list features 2>/dev/null | grep -i "pixel_2026"
} > /data/local/tmp/ramblerport_boot.log 2>&1
