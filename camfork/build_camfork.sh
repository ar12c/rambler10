#!/bin/sh
# CamFork build script (macOS). Builds camfork.apk with SDK build-tools only
# (no gradle). Stubs in stubs/ are compile-time stand-ins for the Vector/Xposed
# API (the real classes are provided by the Vector framework at runtime).
#
# Usage: sh build_camfork.sh   -> writes camfork.apk
set -e
cd "$(dirname "$0")"

SDK="$HOME/Library/Android/sdk"
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
AJAR=$(ls -d "$SDK"/platforms/android-3*/android.jar | sort -V | tail -1)
echo "build-tools: $BT"
echo "android.jar: $AJAR"

rm -rf out
mkdir -p out/stubs out/classes out/dex

javac --release 8 -cp "$AJAR" -d out/stubs $(find stubs -name '*.java')
javac --release 8 -cp "$AJAR:out/stubs" -d out/classes src/dev/ramblerport/camfork/CamFork.java
"$BT/d8" --release --min-api 26 --output out/dex/ out/classes/dev/ramblerport/camfork/CamFork.class
"$BT/aapt2" link -o out/camfork-unsigned.apk -I "$AJAR" --manifest AndroidManifest.xml -A assets \
    --min-sdk-version 26 --target-sdk-version 26
(cd out/dex && zip -q ../camfork-unsigned.apk classes.dex)

KS=out/ks.keystore
if [ ! -f "$KS" ]; then
  keytool -genkeypair -keystore "$KS" -alias camfork -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass camfork123 -keypass camfork123 -dname "CN=RamblerPort" 2>/dev/null
fi
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:camfork123 --out camfork.apk out/camfork-unsigned.apk
"$BT/apksigner" verify camfork.apk
echo "OK: camfork.apk"
echo
echo "Install + activate:"
echo "  adb install -r camfork.apk"
echo "  adb shell su -c '/data/adb/modules/zygisk_vector/cli modules enable dev.ramblerport.camfork'"
echo "  adb shell su -c '/data/adb/modules/zygisk_vector/cli scope add dev.ramblerport.camfork com.google.android.GoogleCamera/0'"
