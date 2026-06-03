# Claude Code Workflow Template for RealBible Test Harness

## Overview
This template guides Claude Code through the automated test generation and execution workflow using DeepSeek API. Claude Code acts as the orchestrator, coordinating file analysis, AI requests, test generation, and test execution.

## Prerequisites
1. Set environment variable: `export DEEPSEEK_API_KEY="your-api-key"`
2. Ensure Dart/Flutter SDK is installed
3. Project dependencies installed: `flutter pub get`

## Workflow Steps

### Step 1: Analyze Modified Files
```bash
# Platform-independent method using harness utility (recommended)
dart tool/harness/utils.dart list-modified --hours=24 > modified_files.txt

# Alternative Unix-only method (Linux/macOS)
# find lib -name "*.dart" -type f -mtime -1 | grep -v ".g.dart" | grep -v ".freezed.dart" | grep -v ".mocks.dart" > modified_files.txt
```

**Claude Code Action:**
- Run `dart tool/harness/utils.dart list-modified --hours=24` to get list of modified files
- For each file path in the output:
  - Read the file content
  - Identify the main class and function(s) to test
- Alternatively, save output to `modified_files.txt` and read from there

### Step 2: Request Test Generation from DeepSeek
```bash
# Example for a single file
dart tool/harness/deepseek_client.dart test lib/features/auth/presentation/screens/login_screen.dart AuthLoginScreen login
```

**Claude Code Action:**
- For each file, determine appropriate class and function names
- Call DeepSeek client with: file path, content, class name, function name
- Capture JSON response with test code
- Extract `tests` field from response

### Step 3: Wrap Test Code with RealBible Bootstrap
```dart
// DeepSeek returns test blocks only
// Need to wrap with imports and setupRealBibleTestEnv()

// Use the utility function from utils.dart
final wrappedTest = wrapWithTestBootstrap(deepSeekTestCode);
```

**Claude Code Action:**
- Apply `wrapWithTestBootstrap()` to ensure test uses proper Riverpod/SQLite setup
- Verify test includes `@TestOn('vm')` and proper imports
- Save to `test/harness_generated/` directory with timestamp

### Step 4: Execute Generated Tests
```bash
# Run the specific generated test
flutter test test/harness_generated/auth_login_screen_1234567890.dart

# Or run all generated tests
flutter test test/harness_generated/
```

**Claude Code Action:**
- Run `flutter test` on generated test file
- Capture output and exit code
- Parse test results using `tool/harness/runner.dart`
- Report success/failure statistics

### Step 5: Request Code Review (Optional)
```bash
# If tests fail, request code review
dart tool/harness/deepseek_client.dart review lib/features/auth/presentation/screens/login_screen.dart
```

**Claude Code Action:**
- If test failures > threshold (e.g., >20%), request code review
- Analyze review suggestions
- Apply fixes or report issues to developer

### Step 6: Cleanup and Reporting
```bash
# Generate test report
dart tool/harness/runner.dart generate-report --output test_report.json

# Optionally clean old generated tests (older than 7 days)
find test/harness_generated -name "*.dart" -type f -mtime +7 -delete
```

**Claude Code Action:**
- Generate summary report in markdown format
- Include: files tested, tests generated, pass/fail rates, coverage if available
- Store report in `test_reports/` directory with timestamp

## Full Automation Script Example
```bash
#!/bin/bash
# automate_test_generation.sh

set -e

# Step 1: Find modified files
MODIFIED_FILES=$(find lib -name "*.dart" -type f -mtime -1 | grep -v ".g.dart" | grep -v ".freezed.dart" | head -10)

for FILE in $MODIFIED_FILES; do
    echo "Processing: $FILE"

    # Extract class name (simplified)
    CLASS_NAME=$(basename "$FILE" .dart)

    # Step 2: Generate tests
    RESPONSE=$(dart tool/harness/deepseek_client.dart test "$FILE" "$CLASS_NAME" "main")
    TEST_CODE=$(echo "$RESPONSE" | jq -r '.tests')

    # Step 3: Save wrapped test
    TIMESTAMP=$(date +%s)
    OUTPUT_FILE="test/harness_generated/${CLASS_NAME}_${TIMESTAMP}.dart"

    # Wrap with bootstrap (implement in separate script)
    dart -e "
      import 'tool/harness/utils.dart';
      main() {
        print(wrapWithTestBootstrap('$TEST_CODE'));
      }
    " > "$OUTPUT_FILE"

    # Step 4: Run tests
    flutter test "$OUTPUT_FILE" || echo "Tests failed for $FILE"
done
```

## Claude Code Prompt Template
When running this workflow, use this prompt structure:

```
I need to run the RealBible test harness workflow. Here's what to do:

1. **Find modified files:** List Dart files modified in the last 24 hours, excluding auto-generated files (.g.dart, .freezed.dart, .mocks.dart).

2. **For each file:**
   - Read the file content
   - Identify the main class and primary function
   - Run DeepSeek test generation:
     ```bash
     dart tool/harness/deepseek_client.dart test <file_path> <class_name> <function_name>
     ```
   - Extract the test code from JSON response
   - Wrap with RealBible test bootstrap using `wrapWithTestBootstrap()`
   - Save to `test/harness_generated/<class>_<timestamp>.dart`

3. **Execute tests:**
   - Run `flutter test` on each generated file
   - Capture results and report pass/fail counts
   - If failure rate > 20%, request code review for problematic files

4. **Generate report:**
   - Create markdown summary with statistics
   - Include any critical issues found
   - Save to `test_reports/<date>.md`

Proceed step by step and show me the results at each stage.
```

## Safety Gates
- **DB Schema Changes:** If modified files include `lib/core/data/local/drift/`, prompt for manual review
- **Authentication/Security:** If files in `lib/features/auth/` modified, ensure tests don't expose secrets
- **Build Breakage:** If `flutter test` fails catastrophically, stop and report
- **API Limits:** Monitor DeepSeek API usage; stop if quota approaching

## Notes
- The harness is designed for incremental testing, not full test suite generation
- Generated tests should complement existing tests, not replace them
- Always verify AI-generated tests for correctness before committing
- Clean up generated test files regularly to avoid clutter