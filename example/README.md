# real_page_flip example

The default example starts in the lightweight `medium` performance profile,
matching the package defaults.

## Performance Benchmark

Run the benchmark on a physical device in profile mode:

```bash
flutter run --profile -t lib/performance_benchmark.dart --dart-define=PERFORMANCE_PROFILE=medium --dart-define=DOUBLE_SPREAD=false --dart-define=FLIPS=80
```

Set `DOUBLE_SPREAD=true` to measure two-page spread mode. The benchmark reports
`FrameTiming` build/raster averages, P90/P99, max frame time, and jank count.

## Physical swipe-release verification

`lib/release_validation.dart` is a separate fixture with no autoplay. It starts
on page 3 in single-page mode using the default medium profile. Its footer marks
pointer release and subsequent settle frames; logcat emits `RELEASE_FRAME` and
`RELEASE_DONE` with progress, layer activity, elapsed time, and page indices.
The fixture keeps its own Android window awake while foregrounded, without
changing the system screen timeout or lock settings.

Run the fixture in profile mode with `-t lib/release_validation.dart`; add
`--dart-define=HIGH_PROFILE=true` for the high profile. Use a separate Android
application ID when the device already contains another app with the example's
application ID, so its installation and data are preserved.

With the system's remove-animations setting enabled, verify a short drag that
returns to the same page and a drag past the cutoff that completes the turn, in
both directions. The moving sheet must remain visible after pointer-up until
its endpoint. Compare the recording against the release markers, rather than
judging only the finger-down portion of the swipe.

Use ordinary `adb pull` to collect recordings. If it resets the USB connection,
check the actual USB topology and transport errors before accepting a transfer
workaround. During the SM-S948N validation, the original Genesys hub path
reported a USB transaction error; reconnecting to a different rear motherboard
USB path restored normal transfers. Five 128 MiB pulls, including an ADB server
restart, completed with matching SHA-256 hashes. See the
[device validation record](device-validation-2026-11-07.md).

For diagnostic recovery while a USB fault is still being investigated, the
repository also provides a slow, resumable fallback using small shell replies
and whole-file SHA-256 validation:

```bash
python tool/pull_device_file.py --serial DEVICE_SERIAL /data/local/tmp/recording.mp4 build/recording.mp4
```

Run the command from the repository root. It never changes device settings or
publishes an output whose hash does not match the device file. Stop the fixture
after verification to release its foreground keep-screen-on window.
