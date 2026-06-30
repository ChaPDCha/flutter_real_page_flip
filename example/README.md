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
