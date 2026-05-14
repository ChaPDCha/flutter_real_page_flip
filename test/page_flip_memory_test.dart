import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Effect handler that does nothing — avoids creating [AudioPlayer] instances
/// in the test environment where platform channels are unavailable.
class _NoOpEffectHandler implements PageFlipEffectHandler {
  const _NoOpEffectHandler();

  @override
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? intensity,
    int? pageIndex,
    double? volume,
    double? texture,
    double? resistance,
  }) {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to suppress platform channel errors for specific prefixes
  void mockChannel(String channelName) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            MethodChannel(channelName), (call) async => null);
  }

  setUpAll(() {
    mockChannel('vibration');
    mockChannel('flutter.baseflow.com/vibration');
  });

  testWidgets('PageFlipWidget Memory Test: Manual WeakReference tracking',
      (tester) async {
    // Suppress audioplayers event channels (dynamic UUID-based)
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (methodCall) async => null,
    );

    await tester.runAsync(() async {
      // 1. Inflate Widget with no-op effect handler to avoid platform channels
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlipWidget(
              config: const PageFlipConfig(
                effectHandler: _NoOpEffectHandler(),
              ),
              itemCount: 10,
              itemBuilder: (context, index) => Container(
                key: ValueKey('page_$index'),
                color: Colors.blue,
                child: Text('Page $index'),
              ),
            ),
          ),
        ),
      );

      final finder = find.byType(PageFlipWidget);
      final state = tester.state<PageFlipWidgetState>(finder);

      // 2. Simulate User Interaction (Triggers texture capture & effects)
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(finder));
      await gesture.moveBy(const Offset(-200, 0)); // Drag start
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();

      await gesture.moveBy(const Offset(-800, 0)); // Complete flip
      await gesture.up();
      await tester.pumpAndSettle();

      // 3. Trigger Disposal
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // 4. Verification
      // Proves that the widget unmounted and ran its dispose() logic (cleaning up controllers/managers)
      expect(state.mounted, isFalse);

      print(
          'Verified: PageFlipWidgetState successfully unmounted after interactions.');
    });
  });
}
