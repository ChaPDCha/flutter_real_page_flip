///
/// Test scaffold generator.
///
/// Usage:
///   dart run tool/generate_test.dart path/to/feature
///
/// This creates test/path/to/feature_test.dart with a basic test template.
///
library;

import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run tool/generate_test.dart path/to/feature');
    exit(1);
  }

  final featurePath = arguments.first;

  // Normalize path separators to forward slash
  final normalized = featurePath.replaceAll('\\', '/');

  // Derive the import path from the feature path
  // Example: "controllers/page_flip_controller" -> "page_flip_controller"
  final segments = normalized.split('/');
  final featureName = segments.last;

  // Build the test file path: test/<featurePath>_test.dart
  final testFilePath = 'test/${normalized}_test.dart';
  final testFile = File(testFilePath);

  if (testFile.existsSync()) {
    stderr.writeln('ERROR: $testFilePath already exists.');
    exit(1);
  }

  // Ensure parent directories exist
  testFile.parent.createSync(recursive: true);

  // Generate the test scaffold content
  final description = featureName
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'\b\w'),
        (m) => m.group(0)!.toUpperCase(),
      );

  final buffer = StringBuffer();
  buffer.writeln("import 'package:flutter_test/flutter_test.dart';");
  buffer.writeln('');
  buffer.writeln("import 'package:real_page_flip/page_flip.dart';");
  buffer.writeln('');
  buffer.writeln('void main() {');
  buffer.writeln("  group('$description', () {");
  buffer.writeln("    test('TODO: describe what this test verifies', () {");
  buffer.writeln('      // Arrange');
  buffer.writeln('');
  buffer.writeln('      // Act');
  buffer.writeln('');
  buffer.writeln('      // Assert');
  buffer.writeln('    });');
  buffer.writeln('  });');
  buffer.writeln('}');

  testFile.writeAsStringSync(buffer.toString());

  print('Created: $testFilePath');
  print('');
  print('Next steps:');
  print('  1. Replace TODO with a meaningful test description.');
  print('  2. Add import statements for the source files under test.');
  print('  3. Implement the test logic.');
}
