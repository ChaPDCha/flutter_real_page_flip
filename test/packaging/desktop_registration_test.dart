import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:yaml/yaml.dart';

/// Flutter's generated `dart_plugin_registrant.dart` imports
/// `package:real_page_flip/real_page_flip.dart` and calls
/// `<dartPluginClass>.registerWith()` on the matching host platform. A class
/// that is only declared in pubspec.yaml, but not exported from that library,
/// breaks the Dart compile of every platform, not just the desktop one.
void main() {
  // Every desktop registration class pubspec.yaml can name, by class name.
  final hooks = <String, void Function()>{
    'RealPageFlipWindows': RealPageFlipWindows.registerWith,
    'RealPageFlipMacos': RealPageFlipMacos.registerWith,
    'RealPageFlipLinux': RealPageFlipLinux.registerWith,
  };

  test('desktop registration hooks do nothing', () {
    for (final hook in hooks.values) {
      expect(hook, returnsNormally);
    }
  });

  test('every dartPluginClass in pubspec.yaml is exported and known here', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final platforms = ((pubspec['flutter'] as YamlMap)['plugin']
        as YamlMap)['platforms'] as YamlMap;

    final declared = <String>{
      for (final declaration in platforms.values)
        if ((declaration as YamlMap)['dartPluginClass'] case final String name)
          name,
    };

    expect(declared, isNotEmpty);
    expect(hooks.keys, containsAll(declared));
  });
}
