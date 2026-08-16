#!/system/bin/sh
D=/data/app/~~ZNYiwLyNSKa6GIwRJOnt7Q==/com.google.android.GoogleCamera-28JrnbRHe3rbLdUqyxkZ7g==
OUT=/data/local/tmp/magic2.txt
: > $OUT
for f in $D/base.apk $D/split_*.apk; do
  strings "$f" 2>/dev/null | grep -iE 'magic.?capture' >> $OUT
done
sort -u $OUT -o $OUT
echo "unique hits: $(wc -l < $OUT)"
head -20 $OUT
