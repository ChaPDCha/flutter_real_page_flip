# Flutter Real Page Flip - Makefile
# Compatible with Linux, macOS, and Windows (Git Bash)

.PHONY: test analyze check test-watch coverage format

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
