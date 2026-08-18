package dev.ramblerport.camfork;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/**
 * RamblerPort camera isolation.
 * The device runs a global yogi (Pixel 11 Pro Fold) identity for Rambler.
 * Pixel Camera's device table (htb -> rbf.c(MANUFACTURER, DEVICE, FINGERPRINT))
 * throws UnsupportedOperationException on unknown Build.DEVICE, so inside the
 * GoogleCamera process ONLY we overwrite Build back to stock rango.
 * Vector loads this before handleBindApplication installs providers, i.e.
 * before CameraContentProvider -> htb.<init> runs.
 */
public class CamFork implements IXposedHookLoadPackage {
    private static final String GCAM = "com.google.android.GoogleCamera";
    private static final String RANGO_FP =
            "google/rango/rango:17/CP2A.260805.005/15828068:user/release-keys";

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam lpparam) {
        if (!GCAM.equals(lpparam.packageName)) return;
        set("DEVICE", "rango");
        set("PRODUCT", "rango");
        set("MODEL", "Pixel 10 Pro Fold");
        set("FINGERPRINT", RANGO_FP);
    }

    private static void set(String field, String value) {
        try {
            XposedHelpers.setStaticObjectField(android.os.Build.class, field, value);
        } catch (Throwable ignored) {
            // never break the host app
        }
    }
}
