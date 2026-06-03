/// Utility functions for the test harness.
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Strips JSON markdown wrapper from text.
///
/// DeepSeek API often returns JSON wrapped in markdown code blocks like:
/// ```json
/// { "key": "value" }
/// ```
///
/// This function safely extracts the JSON content.
String stripJsonMarkdown(String text) {
  // Pattern to match ```json ... ``` or ``` ... ```
  final pattern = RegExp(r'^```(?:json)?\s*\n?(.*?)\n?```\s*$', dotAll: true);

  final match = pattern.firstMatch(text);
  if (match != null && match.groupCount >= 1) {
    return match.group(1)!.trim();
  }

  // Also handle cases where there might be trailing whitespace or newlines
  return text.trim();
}

/// Parses JSON from text that may be wrapped in markdown.
Map<String, dynamic> parseJsonWithMarkdownWrapper(String text) {
  final cleaned = stripJsonMarkdown(text);
  return jsonDecode(cleaned) as Map<String, dynamic>;
}

/// Lists Dart files in a directory, excluding auto-generated files.
///
/// Excludes: *.g.dart, *.freezed.dart, *.mocks.dart, *.gr.dart
List<String> listDartFiles(String directory, {bool recursive = true}) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    return [];
  }

  final files = dir
      .listSync(recursive: recursive)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList();

  // Filter out auto-generated files
  final excludedPatterns = [
    RegExp(r'\.g\.dart$'),
    RegExp(r'\.freezed\.dart$'),
    RegExp(r'\.mocks\.dart$'),
    RegExp(r'\.gr\.dart$'),
  ];

  return files.where((filePath) {
    for (final pattern in excludedPatterns) {
      if (pattern.hasMatch(filePath)) {
        return false;
      }
    }
    return true;
  }).toList();
}

/// Finds recently modified Dart files (excluding auto-generated).
///
/// Returns files modified within the last [hours] hours.
List<String> findRecentlyModifiedDartFiles({
  String directory = 'lib',
  int hours = 24,
}) {
  final cutoff = DateTime.now().subtract(Duration(hours: hours));
  final files = listDartFiles(directory);

  return files.where((filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final modified = file.lastModifiedSync();
    return modified.isAfter(cutoff);
  }).toList();
}

/// Reads file content with fallback for empty files.
Future<String> safeReadFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) {
    return '';
  }

  try {
    final content = await file.readAsString();
    return content.trim().isEmpty ? '' : content;
  } catch (e) {
    return '';
  }
}

/// Writes content to a file, creating directories if needed.
Future<void> safeWriteFile(String filePath, String content) async {
  final file = File(filePath);
  final dir = file.parent;

  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }

  await file.writeAsString(content);
}

/// Generates a test file path in the harness_generated directory.
String generateTestFilePath(String baseName) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final safeName = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return path.join('test', 'harness_generated', '${safeName}_$timestamp.dart');
}

/// Checks if a file contains the test bootstrap setup.
bool hasTestBootstrap(String content) {
  // Check if it already has full test structure with imports
  final hasFlutterTestImport = content.contains(
    'import \'package:flutter_test/flutter_test.dart\'',
  );
  final hasMainFunction = content.contains('void main()');

  // If it has both, it's already a complete test file
  if (hasFlutterTestImport && hasMainFunction) {
    return true;
  }

  // If it contains setupRealBibleTestEnv but missing imports/main, still needs wrapping
  return false;
}

/// Wraps test content with the RealBible test bootstrap if needed.
String wrapWithTestBootstrap(String testContent) {
  // If already has bootstrap, return as-is
  if (hasTestBootstrap(testContent)) {
    return testContent;
  }

  // Wrap with the standard test template
  return '''
@TestOn('vm') // SQLite FFI는 VM 환경에서만 동작
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/test_bootstrap.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = setupRealBibleTestEnv();
  });

  tearDown(() {
    // container.dispose()는 setupRealBibleTestEnv에서 자동 처리됨
  });

$testContent
}
''';
}

/// Extracts test logic from DeepSeek response.
///
/// Tries to extract just the test() blocks from the response.
String extractTestLogic(String deepSeekResponse) {
  // Look for test('...') { ... } blocks
  final testBlockPattern = RegExp(r'test\(.*?\)\s*\{.*?\}', dotAll: true);

  final matches = testBlockPattern.allMatches(deepSeekResponse);
  if (matches.isNotEmpty) {
    return matches.map((m) => m.group(0)!).join('\n\n');
  }

  // If no test blocks found, return the whole response
  return deepSeekResponse;
}

/// Creates a summary of test results for reporting.
String createTestSummary(
  int totalTests,
  int passedTests,
  int failedTests,
  int skippedTests,
  Duration totalTime,
) {
  final percentage = totalTests > 0 ? (passedTests / totalTests * 100) : 0;

  return '''
Test Results:
- Total: $totalTests
- Passed: $passedTests (${percentage.toStringAsFixed(1)}%)
- Failed: $failedTests
- Skipped: $skippedTests
- Time: ${totalTime.inMilliseconds}ms
''';
}

/// Command-line interface for utility functions.
void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart utils.dart <command> [options]');
    print('Commands:');
    print('  list-modified [--hours=24]  - List recently modified Dart files');
    print('  wrap-bootstrap <content>    - Wrap test content with bootstrap');
    return;
  }

  final command = args[0];

  switch (command) {
    case 'list-modified':
      int hours = 24;
      for (final arg in args.skip(1)) {
        if (arg.startsWith('--hours=')) {
          hours = int.tryParse(arg.substring('--hours='.length)) ?? 24;
        }
      }
      final files = findRecentlyModifiedDartFiles(hours: hours);
      for (final file in files) {
        print(file);
      }
      break;

    case 'wrap-bootstrap':
      if (args.length < 2) {
        print('Usage: dart utils.dart wrap-bootstrap <test_content>');
        return;
      }
      // Join remaining args as content (in case of spaces)
      final content = args.skip(1).join(' ');
      print(wrapWithTestBootstrap(content));
      break;

    default:
      print('Unknown command: $command');
      break;
  }
}
