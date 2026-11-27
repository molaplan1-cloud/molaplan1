# Molaplan release (R8) keep rules.
#
# v0.19.1 hotfix (t299u): v0.18.0–v0.19.0 crashed on every start. R8 removed the no-arg
# constructor of androidx.work.impl.WorkDatabase_Impl, which Room creates by reflection, so
# androidx.startup's WorkManagerInitializer threw "NoSuchMethodException:
# WorkDatabase_Impl.<init> []" before any activity, service or receiver could run.
# tool/android/verify_release_apk.sh checks the built APK for these constructors.

# Room creates generated databases reflectively (Class.forName(..._Impl).newInstance()).
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.room.paging.**

# WorkManager instantiates workers by class name with (Context, WorkerParameters).
-keep class * extends androidx.work.ListenableWorker { <init>(android.content.Context, androidx.work.WorkerParameters); }
-keep class androidx.work.** { *; }

# Our own components are referenced from the manifest, widgets and WorkManager by name.
-keep class com.molaplan.molaplan.** { *; }
