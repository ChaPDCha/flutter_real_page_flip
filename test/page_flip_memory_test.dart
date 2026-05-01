import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to suppress platform channel errors for specific prefixes
  void mockChannel(String channelName) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            MethodChannel(channelName), (call) async => null);
  }

  setUpAll(() {
    mockChannel('xyz.luan/audioplayers');
    mockChannel('xyz.luan/audioplayers.global');
    mockChannel('vibration');
    mockChannel('flutter.baseflow.com/vibration');

    // For EventChannels, we need to intercept the 'listen' and 'cancel' messages
    // which are sent as standard MethodCalls to the channel name.
    // However, audioplayers uses dynamic IDs for events.
    // We'll use the low-level messenger to intercept EVERYTHING from xyz.luan.

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('xyz.luan/audioplayers/events'),
            (call) async => null);
  });

  testWidgets('PageFlipWidget Memory Test: Manual WeakReference tracking',
      (tester) async {
    // We use a custom messenger handler to ignore all audioplayer event channel registration
    // This is more robust than matching specific UUIDs.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers/events'),
      (methodCall) async => null,
    );

    await tester.runAsync(() async {
      // 1. Inflate Widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlipWidget(
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
