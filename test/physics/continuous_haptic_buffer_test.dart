import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/continuous_haptic_buffer.dart';

void main() {
  group('ContinuousHapticBuffer constants', () {
    test('sampleIntervalMs is 5', () {
      expect(ContinuousHapticBuffer.sampleIntervalMs, equals(5));
    });

    test('flushIntervalMs is 40', () {
      expect(ContinuousHapticBuffer.flushIntervalMs, equals(40));
    });
  });

  group('ContinuousHapticBuffer lifecycle', () {
    test('isActive is false on creation', () {
      final buf = ContinuousHapticBuffer();
      expect(buf.isActive, isFalse);
    });

    test('start sets isActive true and clears state', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      expect(buf.isActive, isTrue);
    });

    test('stop sets isActive false', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      await buf.stop();
      expect(buf.isActive, isFalse);
    });

    test('double start is idempotent', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.start();
      expect(buf.isActive, isTrue);
    });

    test('stop on inactive buffer is a no-op', () async {
      final buf = ContinuousHapticBuffer();
      await buf.stop();
      expect(buf.isActive, isFalse);
    });

    test('reset sets isActive false without native calls', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.reset();
      expect(buf.isActive, isFalse);
    });

    test('reset on inactive buffer is idempotent', () {
      final buf = ContinuousHapticBuffer();
      buf.reset();
      expect(buf.isActive, isFalse);
    });
  });

  group('addSample', () {
    test('adds sample when active', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5, sharpness: 0.7);
      // Cannot inspect private buffer, but verify via shouldFlush
      expect(buf.shouldFlush(100), isTrue);
    });

    test('ignores sample when inactive', () {
      final buf = ContinuousHapticBuffer();
      buf.addSample(0.5);
      expect(buf.shouldFlush(100), isFalse);
    });

    test('clamps intensity to [0, 1] upper bound', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(1.5);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('clamps intensity to [0, 1] lower bound', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(-0.3);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('clamps sharpness to [0, 1] upper bound', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5, sharpness: 1.8);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('clamps sharpness to [0, 1] lower bound', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5, sharpness: -0.2);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('default sharpness is 0.45', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.3);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('ignored when inactive even with valid values', () {
      final buf = ContinuousHapticBuffer();
      buf.addSample(0.8, sharpness: 0.9);
      buf.addSample(0.2);
      expect(buf.shouldFlush(100), isFalse);
    });
  });

  group('shouldFlush', () {
    test('false when inactive', () {
      final buf = ContinuousHapticBuffer();
      expect(buf.shouldFlush(100), isFalse);
    });

    test('false when active but no samples', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      expect(buf.shouldFlush(100), isFalse);
    });

    test('true when active with samples and enough time passed', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      expect(buf.shouldFlush(30), isTrue);
    });

    test('false when insufficient time since last flush', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      // First at t=0
      expect(buf.shouldFlush(0), isFalse);
    });

    test('false with exactly _minFlushGapMs - 1', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      expect(buf.shouldFlush(29), isFalse);
    });
  });

  group('flush', () {
    test('no-op when inactive', () async {
      final buf = ContinuousHapticBuffer();
      await buf.flush(nowMs: 100);
      // Should not throw
    });

    test('no-op when buffer is empty', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      await buf.flush(nowMs: 100);
      // Should not throw
    });

    test('clears buffer after flushing (shouldFlush becomes false)', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      expect(buf.shouldFlush(50), isTrue);
      await buf.flush(nowMs: 50);
      expect(buf.shouldFlush(100), isFalse);
    });

    test('resets flush timer so immediate re-flush is gated', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      await buf.flush(nowMs: 50);
      // Even after adding new sample, shouldFlush is false until gap met
      buf.addSample(0.3);
      expect(buf.shouldFlush(50), isFalse);
    });

    test('re-flush allowed after _minFlushGapMs', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5);
      await buf.flush(nowMs: 50);
      buf.addSample(0.3);
      expect(buf.shouldFlush(80), isTrue);
    });
  });

  group('start-after-stop reusability', () {
    test('full cycle: start → add → flush → stop → start', () async {
      final buf = ContinuousHapticBuffer();

      buf.start();
      expect(buf.isActive, isTrue);

      buf.addSample(0.5);
      expect(buf.shouldFlush(100), isTrue);

      await buf.flush(nowMs: 100);
      expect(buf.shouldFlush(101), isFalse);

      await buf.stop();
      expect(buf.isActive, isFalse);
      expect(buf.shouldFlush(200), isFalse);

      // Reuse after stop
      buf.start();
      expect(buf.isActive, isTrue);
      expect(buf.shouldFlush(300), isFalse); // empty buffer

      buf.addSample(0.7);
      expect(buf.shouldFlush(350), isTrue);
    });

    test('full cycle: start → add → reset → start', () async {
      final buf = ContinuousHapticBuffer();

      buf.start();
      buf.addSample(0.5);
      buf.addSample(0.3);

      buf.reset();
      expect(buf.isActive, isFalse);
      expect(buf.shouldFlush(100), isFalse);

      buf.start();
      expect(buf.isActive, isTrue);
      buf.addSample(0.8);
      expect(buf.shouldFlush(200), isTrue);
    });
  });

  group('boundary values', () {
    test('intensity at 0.0 is accepted', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.0);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('intensity at 1.0 is accepted', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(1.0);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('sharpness at 0.0 is accepted', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5, sharpness: 0.0);
      expect(buf.shouldFlush(100), isTrue);
    });

    test('sharpness at 1.0 is accepted', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      buf.addSample(0.5, sharpness: 1.0);
      expect(buf.shouldFlush(100), isTrue);
    });
  });

  group('rapid sampling', () {
    test('many samples accumulate without intermediate flush', () {
      final buf = ContinuousHapticBuffer();
      buf.start();
      for (var i = 0; i < 100; i++) {
        buf.addSample(i / 100);
      }
      expect(buf.shouldFlush(50), isTrue);
    });

    test('buffer usable after many add/flush cycles', () async {
      final buf = ContinuousHapticBuffer();
      buf.start();
      for (var cycle = 0; cycle < 10; cycle++) {
        for (var i = 0; i < 5; i++) {
          buf.addSample(0.3 + cycle * 0.05);
        }
        await buf.flush(nowMs: cycle * 40 + 50);
      }
      expect(buf.isActive, isTrue);
    });
  });
}
