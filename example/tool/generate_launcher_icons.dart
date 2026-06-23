// One-off launcher icon generator (flutter_launcher_icons lacks build.gradle.kts).
import 'dart:io';

import 'package:image/image.dart' as img;

const _source = 'assets/branding/play_store_icon.png';

const _mipmapSizes = <String, int>{
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

const _foregroundSizes = <String, int>{
  'drawable-mdpi': 108,
  'drawable-hdpi': 162,
  'drawable-xhdpi': 216,
  'drawable-xxhdpi': 324,
  'drawable-xxxhdpi': 432,
};

void main() {
  if (!File(_source).existsSync()) {
    stderr.writeln(
      'Run from example/: dart run tool/generate_launcher_icons.dart',
    );
    exit(1);
  }

  final bytes = File(_source).readAsBytesSync();
  var decoded = img.decodePng(bytes);
  if (decoded == null) {
    stderr.writeln('Failed to decode $_source');
    exit(1);
  }

  if (decoded.width != 512 || decoded.height != 512) {
    decoded = img.copyResize(decoded, width: 512, height: 512);
    File(_source).writeAsBytesSync(img.encodePng(decoded));
  }

  final res = Directory('android/app/src/main/res');
  for (final entry in _mipmapSizes.entries) {
    _writePng(
      res,
      '${entry.key}/ic_launcher.png',
      img.copyResize(decoded, width: entry.value, height: entry.value),
    );
  }

  for (final entry in _foregroundSizes.entries) {
    _writePng(
      res,
      '${entry.key}/ic_launcher_foreground.png',
      img.copyResize(decoded, width: entry.value, height: entry.value),
    );
  }

  _writeColors(res);
  _writeAdaptiveXml(res);
  stdout.writeln('Launcher icons written under android/app/src/main/res');
}

void _writePng(Directory res, String relativePath, img.Image image) {
  final file = File('${res.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
}

void _writeColors(Directory res) {
  final dir = Directory('${res.path}/values');
  dir.createSync(recursive: true);
  File('${dir.path}/colors.xml').writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0D0D0D</color>
</resources>
''');
}

void _writeAdaptiveXml(Directory res) {
  final dir = Directory('${res.path}/mipmap-anydpi-v26');
  dir.createSync(recursive: true);
  File('${dir.path}/ic_launcher.xml').writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');
  File('${dir.path}/ic_launcher_round.xml').writeAsStringSync('''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');
}
