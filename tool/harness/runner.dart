/// Test harness runner for RealBible project.
///
/// Parses `dart test --machine` JSON output and provides structured test results.
import 'dart:convert';
import 'dart:io';

/// Test result from `dart test --machine` output.
class TestResult {
  final String testID;
  final String name;
  final String? result; // "success", "failure", "error"
  final Duration? time;
  final String? error;
  final String? stackTrace;
  final bool hidden;
  final bool skipped;
  final String? skippedReason;

  TestResult({
    required this.testID,
    required this.name,
    this.result,
    this.time,
    this.error,
    this.stackTrace,
    this.hidden = false,
    this.skipped = false,
    this.skippedReason,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testID: json['testID'] as String,
      name: json['name'] as String,
      result: json['result'] as String?,
      time: json['time'] != null
          ? Duration(microseconds: json['time'] as int)
          : null,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      hidden: json['hidden'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
      skippedReason: json['skippedReason'] as String?,
    );
  }

  bool get passed => result == 'success';
  bool get failed => result == 'failure' || result == 'error';

  Map<String, dynamic> toJson() {
    return {
      'testID': testID,
      'name': name,
      'result': result,
      'time': time?.inMicroseconds,
      'error': error,
      'stackTrace': stackTrace,
      'hidden': hidden,
      'skipped': skipped,
      'skippedReason': skippedReason,
    };
  }
}

/// Coverage report summary.
class CoverageReport {
  final int totalLines;
  final int coveredLines;
  final double percentage;

  CoverageReport({
    required this.totalLines,
    required this.coveredLines,
    required this.percentage,
  });

  factory CoverageReport.fromJson(Map<String, dynamic> json) {
    return CoverageReport(
      totalLines: json['totalLines'] as int,
      coveredLines: json['coveredLines'] as int,
      percentage: json['percentage'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalLines': totalLines,
      'coveredLines': coveredLines,
      'percentage': percentage,
    };
  }
}

/// Test execution results.
class TestExecutionResult {
  final List<TestResult> testResults;
  final int totalTests;
  final int passedTests;
  final int failedTests;
  final int skippedTests;
  final Duration totalTime;
  final CoverageReport? coverageReport;

  TestExecutionResult({
    required this.testResults,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
    required this.skippedTests,
    required this.totalTime,
    this.coverageReport,
  });

  factory TestExecutionResult.fromJson(Map<String, dynamic> json) {
    final results = (json['testResults'] as List)
        .map((e) => TestResult.fromJson(e as Map<String, dynamic>))
        .toList();

    return TestExecutionResult(
      testResults: results,
      totalTests: json['totalTests'] as int,
      passedTests: json['passedTests'] as int,
      failedTests: json['failedTests'] as int,
      skippedTests: json['skippedTests'] as int,
      totalTime: Duration(microseconds: json['totalTime'] as int),
      coverageReport: json['coverageReport'] != null
          ? CoverageReport.fromJson(
              json['coverageReport'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'testResults': testResults.map((e) => e.toJson()).toList(),
      'totalTests': totalTests,
      'passedTests': passedTests,
      'failedTests': failedTests,
      'skippedTests': skippedTests,
      'totalTime': totalTime.inMicroseconds,
      'coverageReport': coverageReport?.toJson(),
    };
  }
}

/// Runs tests using `dart test --machine` and parses JSON output.
Future<TestExecutionResult> runTests({
  String directory = 'test',
  List<String> arguments = const [],
}) async {
  final process = await Process.start(
      'dart',
      [
        'test',
        '--machine',
        ...arguments,
      ],
      workingDirectory: Directory(directory).absolute.path);

  final outputLines = <String>[];
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(outputLines.add);

  final errorLines = <String>[];
  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(errorLines.add);

  final exitCode = await process.exitCode;

  if (exitCode != 0 && errorLines.isNotEmpty) {
    stderr.writeln('Test process error: ${errorLines.join('\n')}');
  }

  // Parse JSON lines from output
  final testResults = <TestResult>[];
  for (final line in outputLines) {
    if (line.trim().isEmpty) continue;

    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // Handle different message types from test machine format
      if (json['type'] == 'testDone') {
        testResults.add(TestResult.fromJson(json));
      }
    } catch (e) {
      // Ignore non-JSON lines
    }
  }

  // Calculate summary
  final totalTests = testResults.length;
  final passedTests = testResults.where((r) => r.passed).length;
  final failedTests = testResults.where((r) => r.failed).length;
  final skippedTests = testResults.where((r) => r.skipped).length;

  // Calculate total time (sum of individual test times)
  final totalTime = testResults.fold<Duration>(
    Duration.zero,
    (sum, result) => sum + (result.time ?? Duration.zero),
  );

  return TestExecutionResult(
    testResults: testResults,
    totalTests: totalTests,
    passedTests: passedTests,
    failedTests: failedTests,
    skippedTests: skippedTests,
    totalTime: totalTime,
  );
}

/// Writes test results to a JSON file.
Future<void> writeTestResultsToFile(
  TestExecutionResult results,
  String filePath,
) async {
  final json = results.toJson();
  final jsonString = jsonEncode(json);
  await File(filePath).writeAsString(jsonString);
}

/// Reads test results from a JSON file.
Future<TestExecutionResult> readTestResultsFromFile(String filePath) async {
  final content = await File(filePath).readAsString();
  final json = jsonDecode(content) as Map<String, dynamic>;
  return TestExecutionResult.fromJson(json);
}
