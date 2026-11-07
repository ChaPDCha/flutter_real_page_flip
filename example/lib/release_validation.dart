// Physical-device fixture: real pointer releases, no autoplay or timing overrides.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:real_page_flip/real_page_flip.dart';

const _high = bool.fromEnvironment('HIGH_PROFILE');
const _paper = Color(0xFFF7F1E3);
DevicePerformanceProfile get _profile =>
    _high ? DevicePerformanceProfile.high : DevicePerformanceProfile.medium;

void main() => runApp(const MaterialApp(home: _ReleaseValidation()));

class _ReleaseValidation extends StatefulWidget {
  const _ReleaseValidation();

  @override
  State<_ReleaseValidation> createState() => _ReleaseValidationState();
}

class _ReleaseValidationState extends State<_ReleaseValidation> {
  static const _window = MethodChannel('real_page_flip/performance_benchmark');
  final _bookKey = GlobalKey<PageFlipWidgetState>();
  final _status = ValueNotifier<String>('Ready — drag and release');
  final _clock = Stopwatch()..start();
  int _sequence = 0;
  int _releaseTime = 0;
  int _pageAtRelease = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_keepScreenOn(true));
  }

  Future<void> _keepScreenOn(bool enabled) async {
    try {
      await _window.invokeMethod<bool>('setKeepScreenOn', enabled);
    } on MissingPluginException {
      debugPrint('[RELEASE_VALIDATION] keep-screen-on unavailable');
    } on PlatformException catch (error) {
      debugPrint('[RELEASE_VALIDATION] keep-screen-on: ${error.code}');
    }
  }

  void _released(PointerEvent event) {
    final sequence = ++_sequence;
    // Observe after the gesture layer has handled this same pointer-up event.
    scheduleMicrotask(() {
      if (!mounted) return;
      final controller = _bookKey.currentState!.controller;
      _releaseTime = _clock.elapsedMilliseconds;
      _pageAtRelease = controller.currentIndex;
      debugPrint('[RELEASE] id=$sequence page=$_pageAtRelease '
          'progress=${controller.dragProgress.toStringAsFixed(4)} '
          'settling=${controller.isSettling}');
      _observeRelease(sequence);
    });
  }

  void _observeRelease(int sequence) {
    if (!mounted || sequence != _sequence) return;
    final c = _bookKey.currentState!.controller;
    final elapsed = _clock.elapsedMilliseconds - _releaseTime;
    final message = 'UP +${elapsed}ms  page ${c.currentIndex + 1}\n'
        'progress ${c.dragProgress.toStringAsFixed(3)}  '
        '${c.isSettling ? 'SETTLING' : 'IDLE'}';
    _status.value = message;
    debugPrint('[RELEASE_FRAME] id=$sequence dt=$elapsed '
        'progress=${c.dragProgress.toStringAsFixed(4)} '
        'layer=${c.isDragging} settling=${c.isSettling} '
        'page=${c.currentIndex}');
    if (c.isSettling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _observeRelease(sequence);
      });
    } else {
      debugPrint('[RELEASE_DONE] id=$sequence dt=$elapsed '
          'from=$_pageAtRelease to=${c.currentIndex}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF263238),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'SINGLE / ${_high ? 'HIGH' : 'MEDIUM'} / '
                  'system reduced motion: '
                  '${MediaQuery.disableAnimationsOf(context)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Expanded(
                child: Listener(
                  onPointerDown: (_) => _status.value = 'FINGER DOWN',
                  onPointerUp: _released,
                  onPointerCancel: _released,
                  child: PageFlipWidget(
                    key: _bookKey,
                    itemCount: 6,
                    initialIndex: 2,
                    config: PageFlipConfig(
                      backgroundColor: _paper,
                      enableSound: false,
                      enableHaptics: false,
                      edgeTapWidthRatio: 0,
                      performanceProfile: _profile,
                    ),
                    itemBuilder: (context, index) => ColoredBox(
                      color: _paper,
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAGE ${index + 1}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Drag partway, then lift your finger.\n\n'
                              'The same sheet must stay visible while it '
                              'finishes turning or returns to this page.',
                              style: TextStyle(fontSize: 20, height: 1.6),
                            ),
                            const SizedBox(height: 24),
                            for (var line = 0; line < 7; line++) ...[
                              const Divider(color: Colors.brown),
                              Text('${index + 1} — line ${line + 1}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 76,
                child: Center(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _status,
                    builder: (context, status, _) => Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    unawaited(_keepScreenOn(false));
    _status.dispose();
    super.dispose();
  }
}
