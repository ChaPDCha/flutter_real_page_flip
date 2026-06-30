import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

double get _flapBackStrength => double.tryParse(_flapBackStrengthValue) ?? 0.0;

DevicePerformanceProfile get _performanceProfile => switch (_profileName) {
      'low' => DevicePerformanceProfile.low,
      'high' => DevicePerformanceProfile.high,
      _ => DevicePerformanceProfile.medium,
    };

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
  int _currentIndex = 0;
  int _completedFlips = 0;
  bool _running = false;
  bool _done = false;

  int get _itemCount => _doubleSpread ? (_pageCount / 2).ceil() : _pageCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runBenchmark());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    super.dispose();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!_running) return;
    _timings.addAll(timings);
  }

  Future<void> _runBenchmark() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _running = true;
      _done = false;
      _completedFlips = 0;
      _timings.clear();
    });

    const totalFlips = _warmupFlips + _measuredFlips;
    for (var i = 0; mounted && i < totalFlips; i++) {
      if (i == _warmupFlips) {
        _timings.clear();
      }

      if (_currentIndex >= _itemCount - 1) {
        _controller.previousPage();
      } else {
        _controller.nextPage();
      }

      setState(() {
        _completedFlips = i + 1;
      });
      await Future<void>.delayed(
        const Duration(milliseconds: _flipIntervalMs),
      );
    }

    if (!mounted) return;
    _logSummary();
    setState(() {
      _running = false;
      _done = true;
    });
  }

  void _logSummary() {
    final summary = _FrameSummary(_timings);
    debugPrint('real_page_flip benchmark summary');
    debugPrint('mode=${_doubleSpread ? 'double-spread' : 'single'} '
        'profile=$_profileName pages=$_pageCount flips=$_measuredFlips '
        'warmup=$_warmupFlips intervalMs=$_flipIntervalMs '
        'flapBackStrength=$_flapBackStrength');
    debugPrint(summary.format());
  }

  @override
  Widget build(BuildContext context) {
    final pages = List<Widget>.generate(
      _itemCount,
      _doubleSpread ? _buildSpread : _buildPage,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF11131A),
      body: SafeArea(
        child: Stack(
          children: [
            PageFlipWidget(
              controller: _controller,
              itemCount: pages.length,
              spreadMode: _doubleSpread
                  ? PageFlipSpreadMode.doubleSpread
                  : PageFlipSpreadMode.single,
              config: PageFlipConfig(
                skipTapAnimation: false,
                enableHaptics: false,
                enableSound: false,
                performanceProfile: _performanceProfile,
                flapBackStrength: _flapBackStrength,
                backgroundColor: const Color(0xFFF6F0E3),
              ),
              onPageChanged: (index) {
                _currentIndex = index;
              },
              itemBuilder: (context, index) => pages[index],
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _BenchmarkHud(
                running: _running,
                done: _done,
                completedFlips: _completedFlips,
                totalFlips: _warmupFlips + _measuredFlips,
                timings: _timings,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

class _BenchmarkHud extends StatelessWidget {
  const _BenchmarkHud({
    required this.running,
    required this.done,
    required this.completedFlips,
    required this.totalFlips,
    required this.timings,
  });

  final bool running;
  final bool done;
  final int completedFlips;
  final int totalFlips;
  final List<FrameTiming> timings;

  @override
  Widget build(BuildContext context) {
    final summary = _FrameSummary(timings);
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
            'profile: $_profileName  flips: $completedFlips/$totalFlips\n'
            'state: ${done ? 'done' : running ? 'running' : 'warming'}\n'
            '${summary.format(compact: true)}',
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
}
