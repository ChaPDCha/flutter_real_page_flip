import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:real_page_flip/real_page_flip.dart';

const int _pageCount = int.fromEnvironment('PAGES', defaultValue: 160);
const int _measuredFlips = int.fromEnvironment('FLIPS', defaultValue: 80);
const int _warmupFlips = int.fromEnvironment('WARMUP_FLIPS', defaultValue: 8);
const int _flipIntervalMs =
    int.fromEnvironment('INTERVAL_MS', defaultValue: 520);
const bool _doubleSpread = bool.fromEnvironment('DOUBLE_SPREAD');
const String _flapBackStrengthValue =
    String.fromEnvironment('FLAP_BACK_STRENGTH', defaultValue: '0.0');
const String _profileName =
    String.fromEnvironment('PERFORMANCE_PROFILE', defaultValue: 'medium');
const String _snapshotPolicyName = String.fromEnvironment(
  'SNAPSHOT_REFRESH_POLICY',
  defaultValue: 'whenDirty',
);
const String _maxSnapshotPixelRatioValue = String.fromEnvironment(
  'MAX_SNAPSHOT_PIXEL_RATIO',
  defaultValue: '2.25',
);
const MethodChannel _benchmarkChannel =
    MethodChannel('real_page_flip/performance_benchmark');

double get _flapBackStrength => double.tryParse(_flapBackStrengthValue) ?? 0.0;

DevicePerformanceProfile get _performanceProfile => switch (_profileName) {
      'low' => DevicePerformanceProfile.low,
      'high' => DevicePerformanceProfile.high,
      _ => DevicePerformanceProfile.medium,
    };

PageFlipSnapshotRefreshPolicy get _snapshotRefreshPolicy =>
    switch (_snapshotPolicyName) {
      'always' => PageFlipSnapshotRefreshPolicy.always,
      'whenDirty' => PageFlipSnapshotRefreshPolicy.whenDirty,
      _ => throw ArgumentError.value(
          _snapshotPolicyName,
          'SNAPSHOT_REFRESH_POLICY',
          'Expected always or whenDirty',
        ),
    };

double? get _maxSnapshotPixelRatio {
  if (_maxSnapshotPixelRatioValue == 'none') return null;
  final parsed = double.tryParse(_maxSnapshotPixelRatioValue);
  if (parsed == null || !parsed.isFinite || parsed <= 0) {
    throw ArgumentError.value(
      _maxSnapshotPixelRatioValue,
      'MAX_SNAPSHOT_PIXEL_RATIO',
      'Expected a positive finite number or none',
    );
  }
  return parsed;
}

void main() {
  runApp(const _BenchmarkApp());
}

class _BenchmarkApp extends StatelessWidget {
  const _BenchmarkApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _BenchmarkScreen(),
      );
}

class _BenchmarkScreen extends StatefulWidget {
  const _BenchmarkScreen();

  @override
  State<_BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<_BenchmarkScreen> {
  final PageFlipController _controller = PageFlipController();
  final List<FrameTiming> _timings = <FrameTiming>[];
  final List<Duration> _requestLatencies = <Duration>[];

  late final List<Widget> _fixturePages;
  _PendingFlip? _pendingFlip;
  int _currentIndex = 0;
  int _requestedFlips = 0;
  int _completedFlips = 0;
  bool _running = false;
  bool _collectTimings = false;
  bool _done = false;
  bool _keepScreenOn = false;
  String? _failure;

  int get _itemCount => _doubleSpread ? (_pageCount / 2).ceil() : _pageCount;

  @override
  void initState() {
    super.initState();
    // These widgets include all dense text layout input. Generate them once so
    // benchmark state changes cannot rebuild hundreds of fixture paragraphs.
    _fixturePages = List<Widget>.unmodifiable(
      List<Widget>.generate(
        _itemCount,
        _doubleSpread ? _buildSpread : _buildPage,
      ),
    );
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runBenchmark());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _pendingFlip?.stopwatch.stop();
    if (_keepScreenOn) {
      unawaited(_setKeepScreenOn(false));
    }
    super.dispose();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_collectTimings) return;
    _timings.addAll(timings);
  }

  Future<void> _runBenchmark() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _keepScreenOn = await _setKeepScreenOn(true);
    if (!mounted) {
      if (_keepScreenOn) await _setKeepScreenOn(false);
      return;
    }

    setState(() {
      _running = true;
      _done = false;
      _requestedFlips = 0;
      _completedFlips = 0;
      _failure = null;
      _timings.clear();
      _requestLatencies.clear();
    });
    // Keep the HUD transition itself outside the measured frame window.
    await SchedulerBinding.instance.endOfFrame;

    const totalFlips = _warmupFlips + _measuredFlips;
    try {
      if (_itemCount < 2) {
        throw StateError('PAGES must produce at least two benchmark items.');
      }

      for (var sequence = 0; mounted && sequence < totalFlips; sequence++) {
        if (sequence == _warmupFlips) {
          await _beginMeasuredWindow();
        }

        final cadence = Stopwatch()..start();
        final latency = await _requestAndAwaitFlip();
        cadence.stop();

        // A flip is complete only after PageFlipWidget reports its finalized
        // page through onPageChanged.
        _completedFlips += 1;
        if (sequence >= _warmupFlips) {
          _requestLatencies.add(latency);
        }

        if (sequence + 1 < totalFlips) {
          final remainingMicros =
              const Duration(milliseconds: _flipIntervalMs).inMicroseconds -
                  cadence.elapsedMicroseconds;
          if (remainingMicros > 0) {
            await Future<void>.delayed(
              Duration(microseconds: remainingMicros),
            );
          }
        }
      }

      // onPageChanged precedes the engine's final cleanup/capture scheduling.
      // Let its last frame timing batch arrive before closing the window.
      if (_collectTimings) {
        await SchedulerBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    } on Object catch (error, stackTrace) {
      _failure = '$error';
      debugPrint('real_page_flip benchmark failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _collectTimings = false;
    }

    if (!mounted) return;
    _logSummary();
    if (_keepScreenOn) {
      await _setKeepScreenOn(false);
      _keepScreenOn = false;
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _done = true;
    });
  }

  Future<void> _beginMeasuredWindow() async {
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    _timings.clear();
    _requestLatencies.clear();
    _collectTimings = true;
  }

  Future<Duration> _requestAndAwaitFlip() async {
    if (_pendingFlip != null) {
      throw StateError('A benchmark flip request is already pending.');
    }

    final movesForward = _currentIndex < _itemCount - 1;
    final expectedIndex = _currentIndex + (movesForward ? 1 : -1);
    final pending = _PendingFlip(expectedIndex)..stopwatch.start();
    _pendingFlip = pending;
    _requestedFlips += 1;

    if (movesForward) {
      _controller.nextPage();
    } else {
      _controller.previousPage();
    }

    const timeoutMs = _flipIntervalMs * 4 > 5000 ? _flipIntervalMs * 4 : 5000;
    try {
      return await pending.completer.future.timeout(
        const Duration(milliseconds: timeoutMs),
        onTimeout: () => throw TimeoutException(
          'onPageChanged did not report page $expectedIndex',
          const Duration(milliseconds: timeoutMs),
        ),
      );
    } finally {
      pending.stopwatch.stop();
      if (identical(_pendingFlip, pending)) _pendingFlip = null;
    }
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    final pending = _pendingFlip;
    if (pending == null || pending.completer.isCompleted) return;

    pending.stopwatch.stop();
    if (index != pending.expectedIndex) {
      pending.completer.completeError(
        StateError(
          'Expected page ${pending.expectedIndex}, but engine reported $index.',
        ),
      );
      return;
    }
    pending.completer.complete(pending.stopwatch.elapsed);
  }

  Future<bool> _setKeepScreenOn(bool enabled) async {
    try {
      return await _benchmarkChannel.invokeMethod<bool>(
            'setKeepScreenOn',
            enabled,
          ) ??
          false;
    } on MissingPluginException {
      debugPrint('Keep-screen-on is unavailable on this benchmark platform.');
      return false;
    } on PlatformException catch (error) {
      debugPrint('Could not change keep-screen-on state: ${error.message}');
      return false;
    }
  }

  void _logSummary() {
    final frameSummary = _FrameSummary(_timings);
    final latencySummary = _DurationSummary(_requestLatencies);
    debugPrint('real_page_flip benchmark summary');
    debugPrint('mode=${_doubleSpread ? 'double-spread' : 'single'} '
        'profile=$_profileName pages=$_pageCount requested=$_requestedFlips '
        'completed=$_completedFlips measured=${_requestLatencies.length} '
        'warmup=$_warmupFlips intervalMs=$_flipIntervalMs '
        'snapshotPolicy=$_snapshotPolicyName '
        'maxSnapshotPixelRatio=${_maxSnapshotPixelRatio ?? 'none'} '
        'flapBackStrength=$_flapBackStrength '
        'failure=${_failure ?? 'none'}');
    debugPrint(frameSummary.format());
    debugPrint(latencySummary.format(prefix: 'requestToPageChange'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF11131A),
        body: SafeArea(
          child: Stack(
            children: [
              PageFlipWidget(
                controller: _controller,
                itemCount: _fixturePages.length,
                spreadMode: _doubleSpread
                    ? PageFlipSpreadMode.doubleSpread
                    : PageFlipSpreadMode.single,
                config: PageFlipConfig(
                  skipTapAnimation: false,
                  enableHaptics: false,
                  enableSound: false,
                  performanceProfile: _performanceProfile,
                  snapshotRefreshPolicy: _snapshotRefreshPolicy,
                  maxSnapshotPixelRatio: _maxSnapshotPixelRatio,
                  flapBackStrength: _flapBackStrength,
                  backgroundColor: const Color(0xFFF6F0E3),
                ),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) => _fixturePages[index],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: RepaintBoundary(
                  child: _BenchmarkHud(
                    running: _running,
                    done: _done,
                    requestedFlips: _requestedFlips,
                    completedFlips: _completedFlips,
                    totalFlips: _warmupFlips + _measuredFlips,
                    timings: _timings,
                    requestLatencies: _requestLatencies,
                    failure: _failure,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSpread(int spreadIndex) => Row(
        children: [
          Expanded(child: _buildPage(spreadIndex * 2)),
          Container(width: 1, color: const Color(0x33201810)),
          Expanded(child: _buildPage(spreadIndex * 2 + 1)),
        ],
      );

  Widget _buildPage(int index) => DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF6F0E3)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Psalm 150 style page ${index + 1}',
                style: const TextStyle(
                  color: Color(0xFF31281E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  _denseReaderText(index),
                  style: const TextStyle(
                    color: Color(0xFF2E261D),
                    fontSize: 14,
                    height: 1.42,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  String _denseReaderText(int pageIndex) {
    final buffer = StringBuffer();
    for (var line = 0; line < 34; line++) {
      buffer.writeln(
        '${pageIndex + 1}:${line + 1} Praise the Lord with trumpet, harp, '
        'lyre, strings, pipe, and cymbals. This dense reader paragraph '
        'simulates real scripture text layout under rapid page turns.',
      );
    }
    return buffer.toString();
  }
}

class _PendingFlip {
  _PendingFlip(this.expectedIndex);

  final int expectedIndex;
  final Completer<Duration> completer = Completer<Duration>();
  final Stopwatch stopwatch = Stopwatch();
}

class _BenchmarkHud extends StatelessWidget {
  const _BenchmarkHud({
    required this.running,
    required this.done,
    required this.requestedFlips,
    required this.completedFlips,
    required this.totalFlips,
    required this.timings,
    required this.requestLatencies,
    required this.failure,
  });

  final bool running;
  final bool done;
  final int requestedFlips;
  final int completedFlips;
  final int totalFlips;
  final List<FrameTiming> timings;
  final List<Duration> requestLatencies;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    // Percentile sorting is deliberately skipped while frame timings are being
    // collected. The final HUD is built only after the measurement window.
    final metrics = done
        ? '${_FrameSummary(timings).format(compact: true)}\n'
            '${_DurationSummary(requestLatencies).format(
            prefix: 'requestToPageChange',
            compact: true,
          )}'
        : running
            ? 'metrics: collecting (HUD updates paused)'
            : 'frames=0';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD10131C),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.35,
          ),
          child: Text(
            'real_page_flip profile benchmark\n'
            'mode: ${_doubleSpread ? 'double-spread' : 'single'}  '
            'profile: $_profileName  requested: $requestedFlips  '
            'completed: $completedFlips/$totalFlips\n'
            'snapshot: $_snapshotPolicyName  '
            'max DPR: ${_maxSnapshotPixelRatio ?? 'none'}\n'
            'state: ${failure != null ? 'failed' : done ? 'done' : running ? 'running' : 'warming'}\n'
            '$metrics',
          ),
        ),
      ),
    );
  }
}

class _FrameSummary {
  _FrameSummary(List<FrameTiming> timings) : _timings = List.of(timings);

  static const int _budgetMicros = 16667;

  final List<FrameTiming> _timings;

  String format({bool compact = false}) {
    if (_timings.isEmpty) return 'frames=0';

    final build = _timings.map((timing) => timing.buildDuration).toList();
    final raster = _timings.map((timing) => timing.rasterDuration).toList();
    final total = _timings.map((timing) => timing.totalSpan).toList();
    final jank = total
        .where((duration) => duration.inMicroseconds > _budgetMicros)
        .length;

    final fields = [
      'frames=${_timings.length}',
      'jank=$jank',
      'buildAvg=${_micros(_average(build))}us',
      'buildP90=${_micros(_percentile(build, 0.90))}us',
      'rasterAvg=${_micros(_average(raster))}us',
      'rasterP90=${_micros(_percentile(raster, 0.90))}us',
      'totalP99=${_micros(_percentile(total, 0.99))}us',
      'totalMax=${_micros(_max(total))}us',
    ];

    return compact ? fields.join('  ') : fields.join('\n');
  }
}

class _DurationSummary {
  _DurationSummary(List<Duration> durations)
      : _durations = List<Duration>.of(durations);

  final List<Duration> _durations;

  String format({required String prefix, bool compact = false}) {
    if (_durations.isEmpty) return '${prefix}Count=0';
    final fields = [
      '${prefix}Count=${_durations.length}',
      '${prefix}Avg=${_micros(_average(_durations))}us',
      '${prefix}P50=${_micros(_percentile(_durations, 0.50))}us',
      '${prefix}P90=${_micros(_percentile(_durations, 0.90))}us',
      '${prefix}P99=${_micros(_percentile(_durations, 0.99))}us',
      '${prefix}Max=${_micros(_max(_durations))}us',
    ];
    return compact ? fields.join('  ') : fields.join('\n');
  }
}

Duration _average(List<Duration> durations) {
  final totalMicros = durations.fold<int>(
    0,
    (sum, duration) => sum + duration.inMicroseconds,
  );
  return Duration(microseconds: totalMicros ~/ durations.length);
}

Duration _percentile(List<Duration> durations, double fraction) {
  final sorted = List<Duration>.of(durations)
    ..sort((a, b) => a.inMicroseconds.compareTo(b.inMicroseconds));
  final rawIndex = (sorted.length - 1) * fraction;
  return sorted[rawIndex.round().clamp(0, sorted.length - 1)];
}

Duration _max(List<Duration> durations) => durations.reduce(
      (a, b) => a.inMicroseconds >= b.inMicroseconds ? a : b,
    );

int _micros(Duration duration) => duration.inMicroseconds;
