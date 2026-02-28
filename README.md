# page_flip

A flutter package which will help you to add page flip effect to widgets in your app.

This is a forked version with fixes for `goToPage()` method to properly wait for animations to complete.

## Changes from original

- `goToPage()` method now properly waits for all animations to complete before returning
- Fixed issue where `goToPage()` would return immediately without waiting for animation completion

