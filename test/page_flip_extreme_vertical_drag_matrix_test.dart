import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  group('extreme vertical drag viewport matrix', () {
    const viewportSizes = <Size>[
      Size(320, 568), // compact phone
      Size(390, 844), // modern portrait phone
      Size(412, 915), // tall Android phone
      Size(600, 1024), // small tablet portrait
      Size(800, 600), // tablet landscape / baseline
      Size(1024, 768), // 4:3 tablet landscape
      Size(1366, 768), // desktop / web wide
      Size(768, 1366), // rotated wide device
    ];

    const progressSamples = <double>[0.15, 0.5, 0.85];

    bool hasAreaOverlap(Path a, Path b) {
      final overlap = Path.combine(ui.PathOperation.intersect, a, b);
      return !overlap.getBounds().isEmpty;
    }

    test('clip seams overlap for extreme vertical touch positions', () {
      for (final size in viewportSizes) {
        for (final isDoubleSpread in [false, true]) {
          for (final isForward in [false, true]) {
            for (final progress in progressSamples) {
              for (final dy in [-size.height * 4, 0.0, size.height * 5]) {
                final geo = PageFlipGeometry(
                  progress: progress,
                  isRightToLeft: true,
                  touchOffset: Offset(size.width / 2, dy),
                  size: size,
                  isDoubleSpread: isDoubleSpread,
                  isForward: isForward,
                );

                expect(geo.angle.isFinite, isTrue);
                expect(geo.foldNormal.dx.isFinite, isTrue);
                expect(geo.foldNormal.dy.isFinite, isTrue);

                final flapPath = buildFlapScreenClipPath(geo);
                final adjacentPath = geo.flapRightOfFold
                    ? buildOpenPageClipPath(size, geo)
                    : buildStationaryPageClipPath(size, geo);

                expect(
                  hasAreaOverlap(flapPath, adjacentPath),
                  isTrue,
                  reason: 'No flap/adjacent overlap for size=$size, '
                      'double=$isDoubleSpread, forward=$isForward, '
                      'progress=$progress, dy=$dy, angle=${geo.angle}',
                );
              }
            }
          }
        }
      }
    });

    test('angled flap paint bounds cover vertical clip bleed on every viewport',
        () {
      for (final size in viewportSizes) {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset(size.width / 2, -size.height * 4),
          size: size,
        );

        final bounds = buildFlapPaintBoundsLocal(
          geo,
          verticalBleed: size.height,
        );

        expect(bounds.top, lessThanOrEqualTo(-size.height));
        expect(bounds.bottom, greaterThanOrEqualTo(size.height * 2));
        expect(bounds.width, greaterThan(0));
      }
    });

    test('painter keeps textured flap over the underlay at extreme angles',
        () async {
      const size = Size(800, 600);
      final textureRecorder = ui.PictureRecorder();
      Canvas(textureRecorder).drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFF00FF),
      );
      final texture = await textureRecorder.endRecording().toImage(800, 600);
      addTearDown(texture.dispose);

      for (final isForward in [true, false]) {
        for (final touchY in [-size.height * 4, size.height * 5]) {
          final geo = PageFlipGeometry(
            progress: 0.5,
            isRightToLeft: true,
            touchOffset: Offset(size.width / 2, touchY),
            size: size,
            isDoubleSpread: true,
            isForward: isForward,
          );
          final recorder = ui.PictureRecorder();
          PageFlipPainter(
            progress: 0.5,
            isRightToLeft: true,
            touchOffset: Offset(size.width / 2, touchY),
            paperBackColor: const Color(0xFF00FF00),
            flapFrontImage: texture,
            flapFrontSrcRect: Offset.zero & size,
            isDoubleSpread: true,
            isForward: isForward,
            geo: geo,
            performanceProfile: DevicePerformanceProfile.high,
          ).paint(Canvas(recorder), size);
          final frame = await recorder.endRecording().toImage(800, 600);
          final pixels = await frame.toByteData();
          expect(pixels, isNotNull);

          final flapClip = buildFlapScreenClipPath(geo);
          var flapSamples = 0;
          var textureSamples = 0;
          var exposedUnderlaySamples = 0;
          const stride = 800 * 4;
          for (var y = 2; y < 598; y += 3) {
            for (var x = 2; x < 798; x += 3) {
              if (!flapClip.contains(Offset(x + 0.5, y + 0.5))) continue;
              final offset = y * stride + x * 4;
              final r = pixels!.getUint8(offset);
              final g = pixels.getUint8(offset + 1);
              final b = pixels.getUint8(offset + 2);
              final a = pixels.getUint8(offset + 3);
              if (a < 200) continue;
              flapSamples++;
              if (r > g + 30 && b > g + 30) textureSamples++;
              if (g > r + 40 && g > b + 40) exposedUnderlaySamples++;
            }
          }

          expect(flapSamples, greaterThan(100));
          expect(
            textureSamples / flapSamples,
            greaterThan(0.70),
            reason: 'Most of the visible flap must retain its snapshot texture '
                'for forward=$isForward touchY=$touchY',
          );
          expect(
            exposedUnderlaySamples / flapSamples,
            lessThan(0.02),
            reason: 'The green paper underlay is exposed where the rotated '
                'texture mesh should cover it for forward=$isForward '
                'touchY=$touchY',
          );
          frame.dispose();
        }
      }
    });
  });

  group('PageFlipLayerView host app matrix', () {
    const cases = <({Size size, TextDirection direction, String text})>[
      (
        size: Size(320, 568),
        direction: TextDirection.ltr,
        text: 'In the beginning God created the heavens and the earth.',
      ),
      (
        size: Size(390, 844),
        direction: TextDirection.ltr,
        text: '태초에 하나님이 천지를 창조하시니라.',
      ),
      (
        size: Size(412, 915),
        direction: TextDirection.rtl,
        text: 'في البدء خلق الله السماوات والأرض.',
      ),
      (
        size: Size(1024, 768),
        direction: TextDirection.ltr,
        text: 'Au commencement, Dieu créa les cieux et la terre.',
      ),
      (
        size: Size(1366, 768),
        direction: TextDirection.rtl,
        text: 'בְּרֵאשִׁית בָּרָא אֱלֹהִים.',
      ),
    ];

    testWidgets('renders extreme offscreen drags across host text directions',
        (tester) async {
      for (final c in cases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: c.direction,
              child: Scaffold(
                body: Center(
                  child: SizedBox.fromSize(
                    size: c.size,
                    child: PageFlipLayerView(
                      itemCount: 3,
                      currentIndex: 1,
                      dragProgress: 0.5,
                      isDragging: true,
                      isForward: true,
                      touchPosition:
                          Offset(c.size.width * 2, -c.size.height * 4),
                      pageSnapshots: const {},
                      spreadSnapshots: const {},
                      pageKeys: {
                        for (var i = 0; i < 3; i++) i: GlobalKey(),
                      },
                      constrainedSize: c.size,
                      itemBuilder: (context, index) => ColoredBox(
                        color: const Color(0xFFF7F1E3),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(c.text),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(PageFlipLayerView), findsOneWidget);
      }
    });
  });
}
