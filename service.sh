#!/system/bin/sh
# RamblerPort late-start service: boot-time diagnostics only.
sleep 30
{
  date
  echo "model=$(getprop ro.product.model)"
  echo "device=$(getprop ro.product.device)"
  echo "fingerprint=$(getprop ro.build.fingerprint)"
  echo "xml=$(ls /product/etc/sysconfig/pixel_experience_2026.xml 2>/dev/null || echo MISSING)"
  pm list features 2>/dev/null | grep -i "pixel_2026"
} > /data/local/tmp/ramblerport_boot.log 2>&1
