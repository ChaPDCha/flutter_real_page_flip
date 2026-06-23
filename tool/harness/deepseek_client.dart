/// DeepSeek API client for the test harness.
///
/// Uses pure Dart HTTP client (no Flutter plugins) for CLI environment.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'utils.dart';

/// Configuration for DeepSeek API.
class DeepSeekConfig {
  final String apiKey;
  final String baseUrl;
  final String model;
  final Duration timeout;

  DeepSeekConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.model = 'deepseek-v4-flash',
    this.timeout = const Duration(seconds: 60),
  });

  /// Creates config from environment variables.
  factory DeepSeekConfig.fromEnvironment() {
    final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'DEEPSEEK_API_KEY environment variable not set.\n'
        'Set it with: export DEEPSEEK_API_KEY="your-api-key"',
      );
    }

    return DeepSeekConfig(
      apiKey: apiKey,
      baseUrl: Platform.environment['DEEPSEEK_BASE_URL'] ??
          'https://api.deepseek.com/v1',
      model: Platform.environment['DEEPSEEK_MODEL'] ?? 'deepseek-v4-flash',
      timeout: Duration(
        seconds:
            int.tryParse(Platform.environment['DEEPSEEK_TIMEOUT'] ?? '60') ??
                60,
      ),
    );
  }
}

/// DeepSeek API client.
class DeepSeekClient {
  final DeepSeekConfig config;
  final http.Client _client;

  DeepSeekClient({required this.config}) : _client = http.Client();

  /// Creates a client with configuration from environment variables.
  factory DeepSeekClient.fromEnvironment() {
    return DeepSeekClient(config: DeepSeekConfig.fromEnvironment());
  }

  /// Sends a request to DeepSeek API with system prompt.
  Future<Map<String, dynamic>> sendRequest({
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.7,
    int maxTokens = 4000,
  }) async {
    final url = Uri.parse('${config.baseUrl}/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${config.apiKey}',
    };

    final body = {
      'model': config.model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    try {
      final response = await _client
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(config.timeout);

      if (response.statusCode != 200) {
        throw Exception(
          'DeepSeek API error (${response.statusCode}): ${response.body}',
        );
      }

      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          responseJson['choices'][0]['message']['content'] as String;

      // Parse JSON that may be wrapped in markdown
      return parseJsonWithMarkdownWrapper(content);
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: ${e.message}');
      } else if (e is TimeoutException) {
        throw Exception('Request timeout after ${config.timeout}');
      }
      rethrow;
    }
  }

  /// Requests code review from DeepSeek.
  ///
  /// Returns JSON with: { "review": "text", "issues": [...], "suggestions": [...] }
  Future<Map<String, dynamic>> requestCodeReview({
    required String filePath,
    required String codeContent,
  }) async {
    final systemPrompt = '''
You are an expert Dart/Flutter code reviewer. Analyze the provided code and return a JSON object with:
1. "review": A concise overall assessment
2. "issues": Array of issues found, each with "type" ("critical", "high", "medium", "low"), "description", and "suggestion"
3. "suggestions": Array of general improvement suggestions
4. "score": Numeric score from 0-100

Focus on:
- Null safety and error handling
- Riverpod best practices
- SQLite/Drift usage patterns
- Performance and memory usage
- Security (no hardcoded secrets, input validation)
- Code style and maintainability

Return ONLY valid JSON, no markdown wrapper or extra text.
''';

    final userPrompt = '''
File: $filePath

Code:
```
$codeContent
```

Please review this Dart/Flutter code.
''';

    return sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Requests test case generation from DeepSeek.
  ///
  /// Returns JSON with: { "tests": "Dart test code", "coverage_target": "80%" }
  Future<Map<String, dynamic>> requestTestGeneration({
    required String filePath,
    required String codeContent,
    required String className,
    required String functionName,
  }) async {
    final systemPrompt = '''
You are an expert Dart/Flutter test engineer. Generate comprehensive test cases for the provided code.

Return a JSON object with:
1. "tests": Dart test code containing only test() blocks (no imports, no main() function)
2. "coverage_target": String describing target coverage (e.g., "80%")
3. "test_strategy": Brief description of testing approach

Important constraints for RealBible project:
- The generated test code will be wrapped with setupRealBibleTestEnv() automatically
- Use `container.read(provider)` to access Riverpod providers (a `container` variable is available)
- Mock external dependencies appropriately
- Follow TDD principles: test edge cases, error conditions, happy paths
- Do NOT include @TestOn('vm') or imports - they will be added automatically

Generate only the test() blocks that verify the functionality of the provided code.
Example test block:
```dart
test('should do something', () {
  final provider = container.read(someProvider);
  expect(provider.value, equals(expected));
});
```

Return ONLY valid JSON, no markdown wrapper or extra text.
''';

    final userPrompt = '''
File: $filePath
Class: $className
Function: $functionName

Code:
```
$codeContent
```

Generate comprehensive test cases following RealBible project conventions.
''';

    return sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Requests refactoring suggestions from DeepSeek.
  ///
  /// Returns JSON with: { "refactored_code": "code", "explanation": "text", "improvements": [...] }
  Future<Map<String, dynamic>> requestRefactoring({
    required String filePath,
    required String codeContent,
    required String refactoringGoal,
  }) async {
    final systemPrompt = '''
You are an expert Dart/Flutter refactoring assistant. Suggest improvements for the provided code.

Return a JSON object with:
1. "refactored_code": The improved code (full or relevant sections)
2. "explanation": Brief explanation of changes made
3. "improvements": Array of specific improvements with "type" and "benefit"
4. "complexity_reduction": Boolean indicating if complexity was reduced

Focus on:
- Reducing cyclomatic complexity
- Improving readability and maintainability
- Following SOLID principles
- Enhancing performance where possible
- Fixing anti-patterns

Return ONLY valid JSON, no markdown wrapper or extra text.
''';

    final userPrompt = '''
File: $filePath
Refactoring Goal: $refactoringGoal

Original Code:
```
$codeContent
```

Please suggest refactoring improvements.
''';

    return sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt);
  }

  /// Closes the HTTP client.
  void close() {
    _client.close();
  }
}

/// Command-line interface for DeepSeek client.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart deepseek_client.dart <command> [options]');
    print('Commands:');
    print('  review <file_path>        - Review code in file');
    print('  test <file_path> <class> <function> - Generate tests');
    print('  refactor <file_path> <goal> - Suggest refactoring');
    return;
  }

  final command = args[0];

  try {
    final client = DeepSeekClient.fromEnvironment();

    switch (command) {
      case 'review':
        if (args.length < 2) {
          print('Usage: dart deepseek_client.dart review <file_path>');
          return;
        }
        final filePath = args[1];
        final content = await File(filePath).readAsString();
        final result = await client.requestCodeReview(
          filePath: filePath,
          codeContent: content,
        );
        print(jsonEncode(result));

      case 'test':
        if (args.length < 4) {
          print(
            'Usage: dart deepseek_client.dart test <file_path> <class> <function>',
          );
          return;
        }
        final filePath = args[1];
        final className = args[2];
        final functionName = args[3];
        final content = await File(filePath).readAsString();
        final result = await client.requestTestGeneration(
          filePath: filePath,
          codeContent: content,
          className: className,
          functionName: functionName,
        );
        print(jsonEncode(result));

      case 'refactor':
        if (args.length < 3) {
          print('Usage: dart deepseek_client.dart refactor <file_path> <goal>');
          return;
        }
        final filePath = args[1];
        final goal = args[2];
        final content = await File(filePath).readAsString();
        final result = await client.requestRefactoring(
          filePath: filePath,
          codeContent: content,
          refactoringGoal: goal,
        );
        print(jsonEncode(result));

      default:
        print('Unknown command: $command');
    }

    client.close();
  } catch (e) {
    stderr.writeln('Error: $e');
    exitCode = 1;
  }
}
