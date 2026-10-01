import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Guards the packaging contract that engine unit tests cannot see.
///
/// Declaring desktop platforms as native plugins (`pluginClass`) without any
/// native code passed every other gate (analyze, tests, `pub publish
/// --dry-run`) and still broke every app that targeted those platforms, at
/// CMake/CocoaPods time. These checks read the files Flutter's tooling reads.
void main() {
  final pubspec = _load('pubspec.yaml');
  final environment = pubspec['environment'] as YamlMap;
  final platforms = ((pubspec['flutter'] as YamlMap)['plugin']
      as YamlMap)['platforms'] as YamlMap;

  group('plugin platform declarations', () {
    for (final entry in platforms.entries) {
      final platform = entry.key as String;
      // Web registers through a Dart file; every other platform is built from
      // the project Flutter expects under <package>/<platform>/.
      if (platform == 'web') continue;
      final declaration = entry.value as YamlMap;
      final hasNativeCode = Directory(platform).existsSync();

      test('$platform declares only what it can build', () {
        if (hasNativeCode) {
          expect(
            declaration.containsKey('pluginClass') ||
                declaration.containsKey('dartPluginClass'),
            isTrue,
            reason: '$platform/ exists but pubspec.yaml registers no plugin '
                'class for it.',
          );
          return;
        }
        expect(
          declaration.containsKey('pluginClass'),
          isFalse,
          reason: 'pubspec.yaml declares $platform as a native plugin '
              '(pluginClass), but the package has no $platform/ directory. '
              'Any app targeting $platform then fails to build. Use '
              'dartPluginClass for a Dart-only platform.',
        );
        expect(
          declaration['dartPluginClass'],
          isA<String>(),
          reason: '$platform has no native code, so it needs a '
              'dartPluginClass.',
        );
      });
    }
  });

  group('SDK floor', () {
    final gradle = File('android/build.gradle.kts').readAsStringSync();
    final appliesKotlinPlugin =
        gradle.contains('org.jetbrains.kotlin.android') ||
            gradle.contains('kotlin-android');

    test(
      'built-in Kotlin Android build declares Flutter 3.44',
      () {
        // Flutter's built-in Kotlin guide for plugin authors: the migration
        // needs Flutter 3.44, and the plugin must say so. Older SDKs then fail
        // at pub resolution instead of at the app's Android build.
        expect(
          _atLeast(_lowerBound(environment['flutter'] as String), (3, 44, 0)),
          isTrue,
          reason: 'android/build.gradle.kts relies on built-in Kotlin, which '
              'Flutter supports from 3.44; environment.flutter is '
              '"${environment['flutter']}".',
        );
      },
      skip: appliesKotlinPlugin
          ? 'The Android build applies the Kotlin Gradle Plugin itself.'
          : false,
    );
  });
}

YamlMap _load(String path) =>
    loadYaml(File(path).readAsStringSync()) as YamlMap;

(int, int, int) _lowerBound(String constraint) {
  final match = RegExp(r'>=\s*(\d+)\.(\d+)\.(\d+)').firstMatch(constraint);
  if (match == null) {
    fail('No ">=x.y.z" lower bound in "$constraint".');
  }
  return (int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
}

bool _atLeast((int, int, int) actual, (int, int, int) minimum) {
  if (actual.$1 != minimum.$1) return actual.$1 > minimum.$1;
  if (actual.$2 != minimum.$2) return actual.$2 > minimum.$2;
  return actual.$3 >= minimum.$3;
}
