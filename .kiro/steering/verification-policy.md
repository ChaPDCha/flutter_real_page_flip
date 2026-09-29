---
inclusion: always
---

# Verification policy

- Do **not** add or re-enable GitHub Actions `push` / `pull_request` triggers.
  CI is intentionally thrifty: `verify.yml` runs weekly and on
  `workflow_dispatch` only.
- The verification gate is local: `dart run tool/verify.dart`
  (format, analyze, test, publish dry-run).
- If the working environment cannot run Flutter, say so explicitly in the PR
  and ask the maintainer to run `dart run tool/verify.dart`; never claim tests
  pass without having run them.
