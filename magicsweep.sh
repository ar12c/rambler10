#!/system/bin/sh
D=/data/app/~~ZNYiwLyNSKa6GIwRJOnt7Q==/com.google.android.GoogleCamera-28JrnbRHe3rbLdUqyxkZ7g==
OUT=/data/local/tmp/magic_hits.txt
: > $OUT
for f in $D/base.apk $D/split_*.apk; do
  # scan raw bytes of each apk for telltale strings (cheap, catches uncompressed dex/res)
  if grep -aqiE 'magic.?capture|magiccapture|magic_capture' "$f"; then
    echo "HIT: $f" >> $OUT
  fi
done
echo "done"; cat $OUT
