# Flutter Real Page Flip - Makefile
# Compatible with Linux, macOS, and Windows (Git Bash)

.PHONY: test analyze check test-watch coverage format consumer

test:
	flutter test

analyze:
	flutter analyze

check: format analyze test

test-watch:
	flutter test --reporter expanded --watch

coverage:
	flutter test --coverage && genhtml coverage/lcov.info -o coverage/html

format:
	dart format .

# Builds a fresh app that depends on this package (host desktop + web).
consumer:
	dart tool/verify_consumer.dart
