// Light local gate for vibe coding. Mirrors the manual "Verify" workflow.
// Usage: dart run tool/verify.dart
import 'dart:io';

Future<int> _run(String exe, List<String> args, {String? cwd}) async {
  stdout
      .writeln('\n> $exe ${args.join(' ')}${cwd == null ? '' : '  (in $cwd)'}');
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

/// Refuses to validate a release from content that is not exactly [HEAD].
///
/// `dart pub publish --dry-run` normally performs this check itself, but recent
/// Flutter toolchains can report an untouched `analysis_options.yaml` as dirty
/// on GitHub's Linux runners. Check it explicitly and then validate a Git-free
/// clone below, so a real dirty worktree still fails while the toolchain's
/// false-positive Git probe cannot hide package validation.
Future<int> _requireCleanWorktree() async {
  final result = await Process.run(
    'git',
    const <String>['status', '--porcelain', '--untracked-files=all'],
    runInShell: true,
  );
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    return result.exitCode;
  }
  if ((result.stdout as String).trim().isEmpty) return 0;
  stderr.writeln('FAILED: release validation requires a clean worktree.');
  stderr.write(result.stdout);
  return 1;
}

/// Runs pub's full validation against the exact committed package contents.
///
/// The temporary clone has no `.git` directory, so pub cannot mistake a
/// toolchain-written Git status for a package warning. The preceding clean-tree
/// check makes this equivalent to validating [HEAD], not a partial checkout.
Future<int> _publishDryRunFromCleanClone(String root) async {
  final clone =
      await Directory.systemTemp.createTemp('real_page_flip_publish_');
  try {
    final cloneCode = await _run(
      'git',
      <String>['clone', '--no-local', '--depth', '1', root, clone.path],
    );
    if (cloneCode != 0) return cloneCode;

    await Directory('${clone.path}${Platform.pathSeparator}.git')
        .delete(recursive: true);
    return _run('dart', <String>['pub', 'publish', '--dry-run'],
        cwd: clone.path);
  } finally {
    if (await clone.exists()) await clone.delete(recursive: true);
  }
}

Future<void> main() async {
  final root = Directory.current.path;

  // Check the developer's input before Flutter can refresh generated files
  // such as example/pubspec.lock. The release dry-run below always uses a
  // fresh clone of HEAD, so later tool side effects cannot alter its contents.
  await _step('clean worktree for release validation', _requireCleanWorktree);

  await _step(
      'format',
      () => _run('dart', [
            'format',
            '--output=none',
            '--set-exit-if-changed',
            '.',
          ]));

  await _step('analyze (package)', () => _run('flutter', ['analyze']));

  await _step(
    'analyze (example)',
    () => _run('flutter', ['analyze'],
        cwd: '$root${Platform.pathSeparator}example'),
  );

  await _step('test', () => _run('flutter', ['test']));

  await _step(
    'publish dry-run (clean committed package)',
    () => _publishDryRunFromCleanClone(root),
  );

  stdout.writeln('\nALL GATES PASSED');
}
