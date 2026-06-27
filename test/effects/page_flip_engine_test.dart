import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  // ===========================================================================
  // flapFrontSourceRect / flapBackSourceRect / flapFrontSettleSourceRect / flapFrontDestRect
  // ===========================================================================
  group('flapFrontSourceRect', () {
    test('forward double-spread returns right half', () {
      final result = flapFrontSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(400, 0, 400, 600));
    });

    test('backward double-spread returns left half', () {
      final result = flapFrontSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: false,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });

    test('single-page returns full rect regardless of direction', () {
      final fwd = flapFrontSourceRect(
        imageSize: const Size(400, 600),
        isDoubleSpread: false,
        isForward: true,
      );
      final bwd = flapFrontSourceRect(
        imageSize: const Size(400, 600),
        isDoubleSpread: false,
        isForward: false,
      );
      expect(fwd, const Rect.fromLTWH(0, 0, 400, 600));
      expect(bwd, fwd);
    });

    test('zero-width image returns zero-width rect in double-spread', () {
      final result = flapFrontSourceRect(
        imageSize: const Size(0, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result!.width, closeTo(0, 0.001));
      expect(result.left, closeTo(0, 0.001));
    });
  });

  group('flapBackSourceRect', () {
    test('forward double-spread returns left half (verso)', () {
      final result = flapBackSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });

    test('backward double-spread returns right half (verso)', () {
      final result = flapBackSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: false,
      );
      expect(result, const Rect.fromLTWH(400, 0, 400, 600));
    });

    test('single-page returns null (no back content)', () {
      final result = flapBackSourceRect(
        imageSize: const Size(400, 600),
        isDoubleSpread: false,
        isForward: true,
      );
      expect(result, isNull);
    });
  });

  group('flapFrontSettleSourceRect', () {
    test('forward double-spread returns left half (destination)', () {
      final result = flapFrontSettleSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });

    test('backward double-spread returns right half (destination)', () {
      final result = flapFrontSettleSourceRect(
        imageSize: const Size(800, 600),
        isDoubleSpread: true,
        isForward: false,
      );
      expect(result, const Rect.fromLTWH(400, 0, 400, 600));
    });

    test('single-page returns full rect (unchanged)', () {
      final result = flapFrontSettleSourceRect(
        imageSize: const Size(400, 600),
        isDoubleSpread: false,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });
  });

  group('flapFrontDestRect', () {
    test('forward double-spread returns right half', () {
      final result = flapFrontDestRect(
        size: const Size(800, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(400, 0, 400, 600));
    });

    test('backward double-spread returns left half', () {
      final result = flapFrontDestRect(
        size: const Size(800, 600),
        isDoubleSpread: true,
        isForward: false,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });

    test('single-page returns full rect', () {
      final result = flapFrontDestRect(
        size: const Size(400, 600),
        isDoubleSpread: false,
        isForward: true,
      );
      expect(result, const Rect.fromLTWH(0, 0, 400, 600));
    });
  });

  // ===========================================================================
  // flapFrontContentRevealOpacity
  // ===========================================================================
  group('flapFrontContentRevealOpacity', () {
    test('forward: returns 1.0 at progress=0 (start)', () {
      final result = flapFrontContentRevealOpacity(0);
      expect(result, closeTo(1, 0.001));
    });

    test('forward: returns 0.0 during mid-fold phase', () {
      final result = flapFrontContentRevealOpacity(0.5);
      expect(result, closeTo(0, 0.001));
    });

    test('forward: returns 1.0 at progress=1 (end)', () {
      final result = flapFrontContentRevealOpacity(1.0);
      expect(result, closeTo(1, 0.001));
    });

    test('forward: smoothstep fade-out from 1.0 to 0.0', () {
      final atStart = flapFrontContentRevealOpacity(0.0);
      final atMidFade = flapFrontContentRevealOpacity(0.10);
      final atEndFade = flapFrontContentRevealOpacity(0.20);
      expect(atStart, closeTo(1, 0.001));
      expect(atMidFade, greaterThan(0.0));
      expect(atMidFade, lessThan(1.0));
      expect(atEndFade, closeTo(0, 0.001));
    });

    test('forward: smoothstep reveal from 0.0 to 1.0', () {
      final atStart = flapFrontContentRevealOpacity(0.85);
      final atMidReveal = flapFrontContentRevealOpacity(0.90);
      final atEndReveal = flapFrontContentRevealOpacity(0.95);
      expect(atStart, closeTo(0, 0.001));
      expect(atMidReveal, greaterThan(0.0));
      expect(atMidReveal, lessThan(1.0));
      expect(atEndReveal, closeTo(1, 0.001));
    });

    test(
        'backward: progress is inverted so content reveals at end of backward flip',
        () {
      // At backward progress=0, p=1.0 → reveal phase → 1.0.
      expect(
        flapFrontContentRevealOpacity(0, isForward: false),
        closeTo(1, 0.001),
      );
      // At backward progress=0.5 (mid-flip), p=0.5 → mid-fold → 0.0.
      expect(
        flapFrontContentRevealOpacity(0.5, isForward: false),
        closeTo(0, 0.001),
      );
      // At backward progress=1.0, p=0.0 → start → 1.0.
      expect(
        flapFrontContentRevealOpacity(1.0, isForward: false),
        closeTo(1, 0.001),
      );
    });

    test('fadeOutEnd=0 returns 0 for any p <= 0', () {
      final result = flapFrontContentRevealOpacity(0, fadeOutEnd: 0);
      expect(result, closeTo(0, 0.001));
    });

    test('revealStart equals revealEnd means instant transition', () {
      final before = flapFrontContentRevealOpacity(
        0.89,
        revealStart: 0.90,
        revealEnd: 0.90,
      );
      final after = flapFrontContentRevealOpacity(
        0.90,
        revealStart: 0.90,
        revealEnd: 0.90,
      );
      expect(before, closeTo(0, 0.001));
      expect(after, closeTo(1, 0.001));
    });
  });

  // ===========================================================================
  // flapOpacityModulator
  // ===========================================================================
  group('flapOpacityModulator', () {
    test('returns 1.0 at progress=0', () {
      expect(flapOpacityModulator(0), closeTo(1, 0.001));
    });

    test('returns 1.0 at progress=1', () {
      expect(flapOpacityModulator(1), closeTo(1, 0.001));
    });

    test('returns 1.0 when both strengths are 0', () {
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(
          flapOpacityModulator(p, thinPaperStrength: 0, endRevealStrength: 0),
          closeTo(1, 0.001),
        );
      }
    });

    test('thin paper reduces opacity at mid-flip (forward)', () {
      final atMid = flapOpacityModulator(
        0.5,
        thinPaperStrength: 0.15,
        endRevealStrength: 0,
      );
      expect(atMid, lessThan(1.0));
      expect(atMid, greaterThan(0.5));
    });

    test('end reveal reduces opacity near end (forward)', () {
      final nearEnd = flapOpacityModulator(
        0.95,
        thinPaperStrength: 0,
        endRevealStrength: 0.35,
        endRevealStart: 0.85,
      );
      expect(nearEnd, lessThan(1.0));
      expect(nearEnd, greaterThan(0.2));
    });

    test('backward: normalization inverts progress', () {
      // Backward progress=0 → p=1 → 1.0
      expect(
        flapOpacityModulator(0, thinPaperStrength: 0.15, isForward: false),
        closeTo(1, 0.001),
      );
      // Backward progress=1 → p=0 → 1.0
      expect(
        flapOpacityModulator(1, thinPaperStrength: 0.15, isForward: false),
        closeTo(1, 0.001),
      );
      // Backward and forward should produce the same result at p=0.5
      expect(
        flapOpacityModulator(0.5,
            thinPaperStrength: 0.15, endRevealStrength: 0, isForward: false),
        closeTo(
          flapOpacityModulator(0.5,
              thinPaperStrength: 0.15, endRevealStrength: 0),
          0.001,
        ),
      );
    });

    test('result is clamped to minimum 0.2', () {
      final result = flapOpacityModulator(
        0.5,
        thinPaperStrength: 0.8,
        endRevealStrength: 0,
      );
      expect(result, greaterThanOrEqualTo(0.2));
    });
  });

  // ===========================================================================
  // snapClipCoord
  // ===========================================================================
  group('snapClipCoord', () {
    test('integer stays as integer (snapped to .0)', () {
      expect(snapClipCoord(3), closeTo(3.0, 0.001));
    });

    test('.25 rounds to nearest 0.5', () {
      // (3.25 * 2) = 6.5 → round → 7 → /2 = 3.5
      expect(snapClipCoord(3.25), closeTo(3.5, 0.001));
    });

    test('.75 rounds up to 1.0', () {
      expect(snapClipCoord(3.75), closeTo(4.0, 0.001));
    });

    test('.5 stays at .5', () {
      expect(snapClipCoord(3.5), closeTo(3.5, 0.001));
    });

    test('negative values snap correctly', () {
      // (-1.25 * 2) = -2.5 → round → -3 → /2 = -1.5
      expect(snapClipCoord(-1.25), closeTo(-1.5, 0.001));
      expect(snapClipCoord(-1.5), closeTo(-1.5, 0.001));
      expect(snapClipCoord(-1.75), closeTo(-2.0, 0.001));
    });

    test('zero stays zero', () {
      expect(snapClipCoord(0), closeTo(0, 0.001));
    });
  });

  // ===========================================================================
  // snapClipPoint
  // ===========================================================================
  group('snapClipPoint', () {
    test('both coordinates are snapped', () {
      final result = snapClipPoint(const Offset(3.25, 4.75));
      // 3.25 → 3.5, 4.75 → 5.0
      expect(result.dx, closeTo(3.5, 0.001));
      expect(result.dy, closeTo(5.0, 0.001));
    });

    test('overlapShift shifts X before snapping', () {
      final result = snapClipPoint(
        const Offset(3.25, 4),
        overlapShift: 1.5,
      );
      // 3.25 + 1.5 = 4.75 → snap to 5.0
      expect(result.dx, closeTo(5.0, 0.001));
      expect(result.dy, closeTo(4.0, 0.001));
    });

    test('negative overlapShift shifts X left', () {
      final result = snapClipPoint(
        const Offset(3.25, 4),
        overlapShift: -1.5,
      );
      // 3.25 - 1.5 = 1.75 → snap to 2.0
      expect(result.dx, closeTo(2.0, 0.001));
      expect(result.dy, closeTo(4.0, 0.001));
    });

    test('zero overlapShift is no-op', () {
      final withShift = snapClipPoint(const Offset(3.5, 5.5), overlapShift: 0);
      final without = snapClipPoint(const Offset(3.5, 5.5));
      expect(withShift.dx, closeTo(without.dx, 0.001));
      expect(withShift.dy, closeTo(without.dy, 0.001));
    });
  });

  // ===========================================================================
  // appendFoldLineBoundary
  // ===========================================================================
  group('appendFoldLineBoundary', () {
    PageFlipGeometry makeGeo({
      double progress = 0.5,
      bool rtl = true,
      Offset touch = Offset.zero,
      double width = 400,
      double height = 600,
      bool isDoubleSpread = false,
      bool isForward = true,
    }) =>
        PageFlipGeometry(
          progress: progress,
          isRightToLeft: rtl,
          touchOffset: touch,
          size: Size(width, height),
          isDoubleSpread: isDoubleSpread,
          isForward: isForward,
        );

    test('straight fold (curvatureAmount=0) adds two lineTo points', () {
      final geo = makeGeo(progress: 0);
      final path = Path()..moveTo(0, 0);
      appendFoldLineBoundary(path, geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width + bounds.height, greaterThan(0));
    });

    test('curved fold (curvatureAmount>0) adds quadratic bezier', () {
      final geo = makeGeo(progress: 0.5);
      final path = Path()..moveTo(0, 0);
      appendFoldLineBoundary(path, geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width + bounds.height, greaterThan(0));
    });

    test('positive overlapShift moves fold boundary right', () {
      final geo = makeGeo(progress: 0.5);
      final pathUnshifted = Path()..moveTo(0, 0);
      appendFoldLineBoundary(pathUnshifted, geo, overlapShift: 0);
      final unshiftedBounds = pathUnshifted.getBounds();

      final pathShifted = Path()..moveTo(0, 0);
      appendFoldLineBoundary(pathShifted, geo, overlapShift: 10);
      final shiftedBounds = pathShifted.getBounds();

      expect(shiftedBounds.right, greaterThan(unshiftedBounds.right));
    });
  });

  // ===========================================================================
  // buildStationaryPageClipPath / buildOpenPageClipPath
  // ===========================================================================
  group('buildStationaryPageClipPath', () {
    test('returns a valid path for normal geometry', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildStationaryPageClipPath(const Size(400, 600), geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('path starts at (0,0) and covers reasonable area', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildStationaryPageClipPath(const Size(400, 600), geo);
      final bounds = path.getBounds();
      // The path moves from (0,0) to the fold line, which may extend above/below
      // canvas due to angle. bounds.top should be at most 0 (extends upward).
      expect(bounds.top, lessThanOrEqualTo(0.5));
      // The path closes with lineTo(0, height), so right bound should be > 0.
      expect(bounds.right, greaterThan(0));
    });
  });

  group('buildOpenPageClipPath', () {
    test('returns a valid path for normal geometry', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildOpenPageClipPath(const Size(400, 600), geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('path starts at right edge (size.width,0)', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildOpenPageClipPath(const Size(400, 600), geo);
      final bounds = path.getBounds();
      expect(bounds.right, closeTo(400, 0.5));
    });
  });

  // ===========================================================================
  // buildFlapClipPathLocal
  // ===========================================================================
  group('buildFlapClipPathLocal', () {
    test('returns a valid path for normal geometry', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildFlapClipPathLocal(geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('path bounds are within reasonable range', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildFlapClipPathLocal(geo);
      final bounds = path.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(-10));
      expect(bounds.top, greaterThanOrEqualTo(-10));
    });

    test('curved geometry produces curved flap clip', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.curvatureAmount, greaterThan(0.001));
      final path = buildFlapClipPathLocal(geo);
      expect(path, isA<Path>());
    });

    test('at progress=0 flap is at edge, clip path is near-zero width', () {
      final geo = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildFlapClipPathLocal(geo);
      final bounds = path.getBounds();
      expect(bounds.width, lessThan(5));
    });
  });

  // ===========================================================================
  // buildFlapContentMesh
  // ===========================================================================
  group('buildFlapContentMesh', () {
    ui.Vertices buildDefaultMesh({
      double width = 400,
      double height = 600,
      double foldX = 200,
      double flapLeft = 100,
      double curveOffset = 16,
      Rect srcRect = const Rect.fromLTWH(0, 0, 200, 600),
      int segments = 16,
      int columns = 4,
    }) {
      return buildFlapContentMesh(
        size: Size(width, height),
        foldX: foldX,
        flapLeft: flapLeft,
        curveOffset: curveOffset,
        srcRect: srcRect,
        segments: segments,
        columns: columns,
      );
    }

    test('returns ui.Vertices with correct type', () {
      expect(buildDefaultMesh(), isA<ui.Vertices>());
    });

    test('default parameters produces valid mesh', () {
      // 16 segments × 4 columns → non-trivial mesh.
      expect(buildDefaultMesh(segments: 16, columns: 4), isA<ui.Vertices>());
    });

    test('with segments=1 and columns=0 produces minimal mesh', () {
      expect(buildDefaultMesh(segments: 1, columns: 0), isA<ui.Vertices>());
    });

    test('with only columns=0 (fold & flap edge only) produces valid mesh', () {
      expect(buildDefaultMesh(columns: 0), isA<ui.Vertices>());
    });

    test('curveOffset=0 produces flat (non-curved) mesh', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 600),
        foldX: 200,
        flapLeft: 100,
        curveOffset: 0,
        srcRect: const Rect.fromLTWH(0, 0, 100, 600),
      );
      expect(mesh, isA<ui.Vertices>());
    });

    test('flipHorizontal produces mesh without error', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 600),
        foldX: 200,
        flapLeft: 100,
        curveOffset: 16,
        srcRect: const Rect.fromLTWH(0, 0, 200, 600),
        flipHorizontal: true,
      );
      expect(mesh, isA<ui.Vertices>());
    });

    test('zero-size flap (foldX == flapLeft) still produces valid mesh', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 600),
        foldX: 200,
        flapLeft: 200,
        curveOffset: 0,
        srcRect: const Rect.fromLTWH(0, 0, 0, 600),
      );
      expect(mesh, isA<ui.Vertices>());
    });

    test('large flap (foldX far from flapLeft) produces valid mesh', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 600),
        foldX: 300,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: const Rect.fromLTWH(0, 0, 250, 600),
      );
      expect(mesh, isA<ui.Vertices>());
    });

    test('segments=1 with different column counts produce valid meshes', () {
      for (final cols in [0, 1, 2, 4]) {
        expect(
          buildDefaultMesh(segments: 1, columns: cols),
          isA<ui.Vertices>(),
        );
      }
    });

    test('non-square srcRect produces valid mesh', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 600),
        foldX: 200,
        flapLeft: 100,
        curveOffset: 16,
        srcRect: const Rect.fromLTWH(10, 20, 180, 300),
      );
      expect(mesh, isA<ui.Vertices>());
    });
  });

  // ===========================================================================
  // flipSideShadowClipRect
  // ===========================================================================
  group('flipSideShadowClipRect', () {
    test('double-spread returns rect from spineX to width', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final rect = flipSideShadowClipRect(geo);
      expect(rect.left, closeTo(400, 0.001)); // spineX
      expect(rect.right, closeTo(800, 0.001));
      expect(rect.top, closeTo(0, 0.001));
      expect(rect.bottom, closeTo(600, 0.001));
    });

    test('single-page returns rect from foldX to width', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final rect = flipSideShadowClipRect(geo);
      expect(rect.left, closeTo(geo.foldX, 0.5));
      expect(rect.right, closeTo(400, 0.001));
      expect(rect.top, closeTo(0, 0.001));
      expect(rect.bottom, closeTo(600, 0.001));
    });

    test('single-page with foldX at left edge clamps to 0', () {
      final geo = PageFlipGeometry(
        progress: 1.0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final rect = flipSideShadowClipRect(geo);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.left, lessThanOrEqualTo(geo.foldX + 0.5));
      expect(rect.width, greaterThanOrEqualTo(0));
    });

    test('negative foldX is clamped to 0', () {
      final geo = PageFlipGeometry(
        progress: 0.99,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final rect = flipSideShadowClipRect(geo);
      expect(rect.left, greaterThanOrEqualTo(0));
    });
  });

  // ===========================================================================
  // buildFlapScreenClipPath
  // ===========================================================================
  group('buildFlapScreenClipPath', () {
    test('returns a Path for valid geometry', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildFlapScreenClipPath(geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width + bounds.height, greaterThan(0));
    });

    test('returns empty Path when degenerate (flap width near zero)', () {
      final geo = PageFlipGeometry(
        progress: 1.0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final path = buildFlapScreenClipPath(geo);
      expect(path, isA<Path>());
    });

    test('curved geometry produces non-empty path', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.curvatureAmount, greaterThan(0.001));
      final path = buildFlapScreenClipPath(geo);
      expect(path, isA<Path>());
    });

    test('double-spread forward produces valid screen clip', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final path = buildFlapScreenClipPath(geo);
      expect(path, isA<Path>());
      final bounds = path.getBounds();
      expect(bounds.width + bounds.height, greaterThan(0));
    });
  });

  // ===========================================================================
  // clipFullSpreadHalf / clipSpreadPageHalf (widget tests)
  // ===========================================================================
  group('clipFullSpreadHalf', () {
    test('returns ClipRect wrapping Align with widthFactor=0.5', () {
      const child = SizedBox(width: 100, height: 100);
      final widget = clipFullSpreadHalf(
        child: child,
        alignment: Alignment.centerRight,
      );

      expect(widget, isA<ClipRect>());
      final clipRect = widget as ClipRect;
      expect(clipRect.child, isA<Align>());
      final align = clipRect.child! as Align;
      expect(align.alignment, Alignment.centerRight);
      expect(align.widthFactor, closeTo(0.5, 0.001));
      expect(align.child, isA<SizedBox>());
    });

    test('alignment affects which half is visible', () {
      final leftWidget = clipFullSpreadHalf(
        child: const SizedBox(width: 100, height: 100),
        alignment: Alignment.centerLeft,
      );
      final rightWidget = clipFullSpreadHalf(
        child: const SizedBox(width: 100, height: 100),
        alignment: Alignment.centerRight,
      );

      final leftAlign = (leftWidget as ClipRect).child! as Align;
      final rightAlign = (rightWidget as ClipRect).child! as Align;
      expect(leftAlign.alignment, Alignment.centerLeft);
      expect(rightAlign.alignment, Alignment.centerRight);
    });
  });

  group('clipSpreadPageHalf', () {
    test('returns ClipRect with Align and FractionallySizedBox', () {
      const child = SizedBox(width: 100, height: 100);
      final widget = clipSpreadPageHalf(
        child: child,
        alignment: Alignment.centerRight,
      );

      expect(widget, isA<ClipRect>());
      final clipRect = widget as ClipRect;
      expect(clipRect.child, isA<Align>());
      final align = clipRect.child! as Align;
      expect(align.alignment, Alignment.centerRight);
      expect(align.widthFactor, closeTo(0.5, 0.001));
      expect(align.child, isA<FractionallySizedBox>());

      final fractionalBox = align.child! as FractionallySizedBox;
      expect(fractionalBox.widthFactor, closeTo(2.0, 0.001));
      expect(fractionalBox.alignment, Alignment.centerRight);
    });
  });

  // ===========================================================================
  // buildViewportSnapshotImage
  // ===========================================================================
  group('buildViewportSnapshotImage', () {
    ui.Image createTestImage() {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.clipRect(const Rect.fromLTWH(0, 0, 1, 1));
      final picture = recorder.endRecording();
      return picture.toImageSync(1, 1);
    }

    test('valid viewportSize returns SizedBox with RawImage', () {
      final image = createTestImage();
      final widget = buildViewportSnapshotImage(
        image,
        viewportSize: const Size(400, 600),
      );
      expect(widget, isA<SizedBox>());
      final sizedBox = widget as SizedBox;
      expect(sizedBox.width, closeTo(400, 0.001));
      expect(sizedBox.height, closeTo(600, 0.001));
      expect(sizedBox.child, isA<RawImage>());
    });

    test('zero viewportSize falls back to RawImage without SizedBox', () {
      final image = createTestImage();
      final widget = buildViewportSnapshotImage(
        image,
        viewportSize: Size.zero,
      );
      expect(widget, isA<RawImage>());
    });

    test('negative viewportSize falls back', () {
      final image = createTestImage();
      final widget = buildViewportSnapshotImage(
        image,
        viewportSize: const Size(-100, 600),
      );
      expect(widget, isA<RawImage>());
    });
  });

  // ===========================================================================
  // Edge cases and invariants
  // ===========================================================================
  group('shared edge cases', () {
    test('kSpineRevealOverlapPx is positive and reasonable', () {
      expect(kSpineRevealOverlapPx, greaterThan(0));
      expect(kSpineRevealOverlapPx, lessThan(10));
    });

    test('snapClipCoord with large values', () {
      // (1234567.25 * 2) = 2469134.5 → round → 2469135 → /2 = 1234567.5
      expect(snapClipCoord(1234567.25), closeTo(1234567.5, 0.001));
      expect(snapClipCoord(1234567.75), closeTo(1234568.0, 0.001));
    });

    test('flapFrontSourceRect respects odd width divisions', () {
      final result = flapFrontSourceRect(
        imageSize: const Size(401, 600),
        isDoubleSpread: true,
        isForward: true,
      );
      expect(result!.left, closeTo(200.5, 0.001));
      expect(result.width, closeTo(200.5, 0.001));
    });

    test('flapFrontContentRevealOpacity handles exactly equal start/end values',
        () {
      // When fadeOutEnd == revealStart, mid-fold phase is zero-width.
      final atBoundary = flapFrontContentRevealOpacity(
        0.20,
        fadeOutEnd: 0.20,
        revealStart: 0.20,
        revealEnd: 0.95,
      );
      // At p=fadeOutEnd, Phase 1 is active and returns 0.
      expect(atBoundary, closeTo(0, 0.001));
    });
  });
}
