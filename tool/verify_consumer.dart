// Builds a throwaway Flutter app that depends on this package.
//
// Unit tests, `flutter analyze` and `pub publish --dry-run` cannot see
// packaging mistakes: a native plugin declared for a platform that has no
// native code, an SDK floor that does not match the Android build, a class
// Flutter's generated registrant cannot import. A fresh app that uses the
// package is what users build, so that is what this builds.
//
// Usage (from the package root):
//   dart tool/verify_consumer.dart [--platforms=windows,web,android] [--keep]
//
// Defaults to the host's desktop platform plus web. Android needs the Android
// SDK; iOS (built without code signing) and macOS need a Mac. To check another
// Flutter version, for example the declared floor, put that SDK's `bin`
// directory first on PATH.
import 'dart:io';

/// `flutter build` arguments per platform.
const _buildArguments = <String, List<String>>{
  'android': ['build', 'apk', '--debug'],
  'ios': ['build', 'ios', '--debug', '--no-codesign'],
  'web': ['build', 'web', '--wasm'],
  'windows': ['build', 'windows', '--debug'],
  'linux': ['build', 'linux', '--debug'],
  'macos': ['build', 'macos', '--debug'],
};

/// The smallest app that still imports the package's public library, which is
/// where Flutter's generated plugin registrant looks for Dart plugin classes.
const _appSource = r'''
import 'package:flutter/material.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: _Book())));

class _Book extends StatelessWidget {
  const _Book();

  @override
  Widget build(BuildContext context) => PageFlipWidget(
        itemCount: 4,
        itemBuilder: (context, index) => Center(child: Text('Page $index')),
      );
}
''';

Future<void> main(List<String> args) async {
  var keep = false;
  List<String>? requested;
  for (final arg in args) {
    if (arg == '--keep') {
      keep = true;
    } else if (arg.startsWith('--platforms=')) {
      requested = arg.substring('--platforms='.length).split(',');
    } else {
      stderr.writeln('Unknown argument: $arg\n'
          'Usage: dart tool/verify_consumer.dart '
          '[--platforms=${_buildArguments.keys.join(',')}] [--keep]');
      exit(64);
    }
  }

  final platforms = requested ?? _defaultPlatforms();
  final unknown = platforms.where((p) => !_buildArguments.containsKey(p));
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown platform(s): ${unknown.join(', ')}. '
        'Known: ${_buildArguments.keys.join(', ')}.');
    exit(64);
  }

  final root = Directory.current.path;
  if (!_isPackageRoot(root)) {
    stderr.writeln('Run this from the real_page_flip package root.');
    exit(64);
  }

  // Inside the package's ignored build/ directory, so the app and the path
  // dependency always share a drive. On Windows a different drive breaks the
  // Kotlin incremental cache of the Android build.
  final work = Directory(_join([root, 'build', 'consumer_check']));
  if (work.existsSync()) work.deleteSync(recursive: true);
  work.createSync(recursive: true);
  final app = _join([work.path, 'app']);

  final setup = <(String, List<String>, String)>[
    (
      'flutter',
      [
        'create',
        '--no-pub',
        '--org',
        'verify.consumer',
        '--project-name',
        'consumer_app',
        '--platforms',
        platforms.join(','),
        'app',
      ],
      work.path,
    ),
    ('flutter', ['pub', 'add', 'real_page_flip', '--path', root], app),
  ];
  for (final (exe, arguments, cwd) in setup) {
    final code = await _run(exe, arguments, cwd: cwd);
    if (code != 0) {
      stderr.writeln('FAILED: could not set up the consumer app (exit $code). '
          'Kept at ${work.path}');
      exit(code);
    }
  }
  File(_join([app, 'lib', 'main.dart'])).writeAsStringSync(_appSource);

  final results = <String, (int, Duration)>{};
  for (final platform in platforms) {
    final watch = Stopwatch()..start();
    final code = await _run('flutter', _buildArguments[platform]!, cwd: app);
    results[platform] = (code, watch.elapsed);
  }

  stdout.writeln('\n=== consumer app summary ===');
  for (final MapEntry(key: platform, value: (code, elapsed))
      in results.entries) {
    stdout.writeln('  ${platform.padRight(8)} '
        '${(code == 0 ? 'OK' : 'FAILED').padRight(7)} ${elapsed.inSeconds}s');
  }

  final failed = results.values.any((result) => result.$1 != 0);
  if (failed || keep) {
    stdout.writeln('Consumer app kept at $app');
  } else {
    work.deleteSync(recursive: true);
  }
  exit(failed ? 1 : 0);
}

/// The host's desktop platform plus web; mobile needs SDKs not every host has.
List<String> _defaultPlatforms() => [
      if (Platform.isWindows) 'windows',
      if (Platform.isLinux) 'linux',
      if (Platform.isMacOS) 'macos',
      'web',
    ];

bool _isPackageRoot(String root) {
  final pubspec = File(_join([root, 'pubspec.yaml']));
  return pubspec.existsSync() &&
      pubspec
          .readAsStringSync()
          .contains(RegExp(r'^name: real_page_flip$', multiLine: true));
}

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

Future<int> _run(String exe, List<String> args, {required String cwd}) async {
  stdout.writeln('\n> $exe ${args.join(' ')}  (in $cwd)');
  final process = await Process.start(
    exe,
    args,
    workingDirectory: cwd,
    runInShell: true,
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  return process.exitCode;
}
