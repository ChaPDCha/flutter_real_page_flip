# RealBible Test Harness

AI-powered test generation and execution harness for RealBible Flutter project.

## Overview

This harness combines Claude Code orchestration with DeepSeek AI to:
1. Analyze modified Dart code
2. Generate comprehensive tests using DeepSeek API
3. Execute tests with proper Riverpod/SQLite mocking
4. Report results and suggest improvements

## Architecture

```
RealBible Test Harness
├── Claude Code (Orchestrator)
│   ├── File analysis
│   ├── Workflow coordination
│   └── Result reporting
├── DeepSeek Client
│   ├── Code review requests
│   ├── Test generation
│   └── Refactoring suggestions
├── Test Runner
│   ├── Dart test execution
│   ├── Result parsing
│   └── Coverage reporting
└── Test Bootstrap
    ├── Riverpod ProviderContainer setup
    └── In-memory SQLite database
```

## Components

### 1. `runner.dart`
- Parses `dart test --machine` JSON output
- Provides `TestResult`, `CoverageReport`, `TestExecutionResult` classes
- Utilities for reading/writing test results

### 2. `utils.dart`
- File I/O utilities
- JSON markdown wrapper stripping (`stripJsonMarkdown()`)
- Auto-generated file exclusion (.g.dart, .freezed.dart, etc.)
- Test bootstrap wrapping (`wrapWithTestBootstrap()`)
- Recently modified file detection

### 3. `deepseek_client.dart`
- Pure Dart HTTP client (no Flutter plugins)
- Environment variable configuration (`DEEPSEEK_API_KEY`)
- Three main functions:
  - `requestCodeReview()` - Code quality analysis
  - `requestTestGeneration()` - Test case generation
  - `requestRefactoring()` - Refactoring suggestions
- JSON markdown wrapper handling

### 4. `claude_workflow.md`
- Step-by-step template for Claude Code
- Complete workflow from file analysis to reporting
- Safety gates and best practices

### 5. `test_bootstrap.dart` (in `test/helpers/`)
- **Critical for AI-generated tests**
- Sets up Riverpod `ProviderContainer` with in-memory SQLite
- Provides `setupRealBibleTestEnv()` function
- Includes test template for DeepSeek to follow

## Installation

1. **Set DeepSeek API key:**
   ```bash
   export DEEPSEEK_API_KEY="your-api-key"
   ```

2. **Install dependencies** (already in project):
   ```bash
   flutter pub get
   ```

3. **Verify environment:**
   ```bash
   dart tool/harness/deepseek_client.dart
   # Should show usage instructions
   ```

## Usage

### Basic Test Generation
```bash
# Generate tests for a specific file
dart tool/harness/deepseek_client.dart test \
  lib/features/auth/presentation/screens/login_screen.dart \
  AuthLoginScreen \
  login
```

### Code Review
```bash
# Review a file for issues
dart tool/harness/deepseek_client.dart review \
  lib/features/auth/presentation/screens/login_screen.dart
```

### Refactoring Suggestions
```bash
# Get refactoring suggestions
dart tool/harness/deepseek_client.dart refactor \
  lib/features/auth/presentation/screens/login_screen.dart \
  "Reduce complexity and improve readability"
```

### Full Claude Code Workflow
See `claude_workflow.md` for complete step-by-step instructions.

## Example: Automated Workflow

```bash
#!/bin/bash
# generate_and_run_tests.sh

# Find modified Dart files (last 24 hours)
MODIFIED_FILES=$(find lib -name "*.dart" -type f -mtime -1 | \
  grep -v ".g.dart" | grep -v ".freezed.dart" | head -5)

for FILE in $MODIFIED_FILES; do
    echo "Processing: $FILE"

    # Extract class name from filename
    CLASS_NAME=$(basename "$FILE" .dart)

    # Generate tests via DeepSeek
    RESPONSE=$(dart tool/harness/deepseek_client.dart test "$FILE" "$CLASS_NAME" "main")
    TEST_CODE=$(echo "$RESPONSE" | jq -r '.tests')

    # Wrap with test bootstrap
    TIMESTAMP=$(date +%s)
    OUTPUT_FILE="test/harness_generated/${CLASS_NAME}_${TIMESTAMP}.dart"

    dart -e "
      import 'tool/harness/utils.dart';
      main() {
        print(wrapWithTestBootstrap('$TEST_CODE'));
      }
    " > "$OUTPUT_FILE"

    # Run tests
    echo "Running tests for $CLASS_NAME..."
    flutter test "$OUTPUT_FILE"
done
```

## Safety Gates

### Critical Checks
1. **No hardcoded secrets** in generated tests
2. **Database migrations** require manual review
3. **Authentication flows** need security validation
4. **API rate limits** monitored

### File Exclusions
- Auto-generated files: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`
- Test harness generated files: `test/harness_generated/`
- Environment files: `.env*`

## Best Practices

### For AI-Generated Tests
1. Always use `setupRealBibleTestEnv()` for Riverpod/SQLite setup
2. Include `@TestOn('vm')` for SQLite FFI compatibility
3. Mock external dependencies (Supabase, network, etc.)
4. Test edge cases and error conditions

### For Claude Code Orchestration
1. Process files incrementally (max 5-10 per run)
2. Verify generated tests before committing
3. Clean up old generated tests regularly
4. Monitor DeepSeek API usage and costs

## Troubleshooting

### Common Issues

1. **"DEEPSEEK_API_KEY not set"**
   ```bash
   export DEEPSEEK_API_KEY="your-key"
   ```

2. **JSON parsing errors**
   - DeepSeek may wrap JSON in markdown blocks
   - `stripJsonMarkdown()` in `utils.dart` handles this

3. **Riverpod/ProviderScope errors**
   - Ensure tests use `setupRealBibleTestEnv()`
   - Check `test_bootstrap.dart` is imported

4. **SQLite FFI errors**
   - Add `@TestOn('vm')` to test files
   - Use `setupSqliteFfiForTests()` (handled by bootstrap)

### Debugging
```bash
# Verbose test output
flutter test -v test/harness_generated/some_test.dart

# Check environment variables
printenv | grep DEEPSEEK

# Test DeepSeek client directly
dart tool/harness/deepseek_client.dart test lib/core/utils/sample.dart Sample main
```

## Contributing

1. Follow existing patterns in `utils.dart` for new utilities
2. Update `claude_workflow.md` when workflow changes
3. Add tests for new harness functionality
4. Document new features in this README

## License

Part of the RealBible project. See main project license.