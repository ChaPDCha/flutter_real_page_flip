// Light local gate for vibe coding. Mirrors the manual "Verify" workflow.
// Usage: dart run tool/verify.dart
import 'dart:io';

Future<int> _run(String exe, List<String> args, {String? cwd}) async {
  stdout.writeln('\n> $exe ${args.join(' ')}${cwd == null ? '' : '  (in $cwd)'}');
  final proc = await Process.start(
    exe,
    args,
    workingDirectory: cwd,
    runInShell: true,
  );
  await Future.wait([
    stdout.addStream(proc.stdout),
    stderr.addStream(proc.stderr),
  ]);
  return proc.exitCode;
}

Future<void> _step(String name, Future<int> Function() fn) async {
  stdout.writeln('\n=== $name ===');
  final code = await fn();
  if (code != 0) {
    stderr.writeln('FAILED: $name (exit $code)');
    exit(code);
  }
}

Future<void> main() async {
  final root = Directory.current.path;

  await _step('format', () => _run('dart', [
        'format',
        '--output=none',
        '--set-exit-if-changed',
        '.',
      ]));

  await _step('analyze (package)', () => _run('flutter', ['analyze']));

  await _step(
    'analyze (example)',
    () => _run('flutter', ['analyze'], cwd: '$root${Platform.pathSeparator}example'),
  );

  await _step('test', () => _run('flutter', ['test']));

  await _step('publish dry-run', () => _run('dart', ['pub', 'publish', '--dry-run']));

  stdout.writeln('\nALL GATES PASSED');
}
