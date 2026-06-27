# ProGuard rules for Realbook Reader
# Only keep the entry point — let ProGuard obfuscate/minify all other classes
-keep class app.realbook.reader.MainActivity { *; }
-dontwarn com.google.android.gms.**
