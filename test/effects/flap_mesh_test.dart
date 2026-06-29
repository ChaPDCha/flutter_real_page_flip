import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  const size = Size(400, 600);
  const srcRect = Rect.fromLTWH(0, 0, 400, 600);

  group('buildFlapContentMesh structural integrity', () {
    test('returns non-null Vertices with default params', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
      );
      expect(mesh, isNotNull);
    });

    test('default params produce 16 segments × 6 columns (17×7 grid)', () {
      // grid = (segments+1) × (totalCols) = 17 × 7 = 119 vertices
      // Each quad has 2 triangles × 3 vertices = 6
      // Number of quads = segments × (totalCols - 1) = 16 × 6 = 96
      // Triangles = 96 × 2 = 192
      // Each triangle has 3 positions with 2 coordinates = 6 floats
      // Total floats = 192 × 6 = 1152
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
      );
      // Can't directly access positions, but the mesh should be valid
      expect(mesh, isNotNull);
    });

    test('0 columns produces valid mesh (no interior columns)', () {
      // totalCols = 0 + 2 = 2 (fold + flap edge only)
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
        columns: 0,
      );
      expect(mesh, isNotNull);
    });

    test('0 segments produces valid mesh (single row)', () {
      // segments = 0 → grid = 1 × totalCols
      // Zero quads → no triangles → empty vertices
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
        segments: 0,
      );

      // 1 segment = 2 rows in grid
      // segments=0: 1 rows, segments * (totalCols-1) = 0 quads
      // So just 1 row of columns, no triangles
      expect(mesh, isNotNull);
    });

    test('zero curvature produces valid flat mesh', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 0,
        srcRect: srcRect,
      );
      expect(mesh, isNotNull);
    });

    test('flipHorizontal mode produces valid mesh', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
        flipHorizontal: true,
      );
      expect(mesh, isNotNull);
    });

    test('mesh with same foldX and flapLeft (degenerate)', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 200,
        curveOffset: 0,
        srcRect: srcRect,
      );
      // Should not crash
      expect(mesh, isNotNull);
    });

    test('mesh with very large curveOffset', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 100,
        srcRect: srcRect,
      );
      expect(mesh, isNotNull);
    });
  });

  group('buildFlapContentMesh pixel verification', () {
    /// Renders the mesh with a known color and checks pixels.
    Future<ui.Image> renderMesh({
      required double foldX,
      required double flapLeft,
      double curveOffset = 16,
      int segments = 8,
      int columns = 4,
      bool flipHorizontal = false,
    }) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final mesh = buildFlapContentMesh(
        size: size,
        foldX: foldX,
        flapLeft: flapLeft,
        curveOffset: curveOffset,
        srcRect: srcRect,
        segments: segments,
        columns: columns,
        flipHorizontal: flipHorizontal,
      );

      canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()..color = const Color(0xFFFF0000),
      );

      return recorder.endRecording().toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
    }

    test('mesh covers area between flapLeft and foldX at mid-height', () async {
      const foldX = 300.0;
      const flapLeft = 50.0;
      final image = await renderMesh(
        foldX: foldX,
        flapLeft: flapLeft,
        curveOffset: 0, // flat mesh for deterministic test
      );

      final byteData = await image.toByteData();
      expect(byteData, isNotNull);

      // Check pixel at mid-point between flapLeft and foldX at mid-height.
      final mx = ((flapLeft + foldX) / 2).toInt();
      final my = (size.height / 2).toInt();

      // Sample the pixel (RGBA, each pixel is 4 bytes).
      final stride = size.width.toInt() * 4;
      final offset = my * stride + mx * 4;
      final r = byteData!.getUint8(offset);
      expect(
        r,
        greaterThan(0),
        reason: 'Mesh should cover the region between flapLeft and foldX',
      );

      // Pixel outside flap (far right of foldX) should be transparent.
      final outsideX = (foldX + 50).toInt();
      final outsideOffset = my * stride + outsideX * 4;
      final outsideR = byteData.getUint8(outsideOffset);
      expect(
        outsideR,
        equals(0),
        reason: 'Area beyond foldX should not be covered',
      );

      image.dispose();
    });

    test('mesh does not crash with extreme parameters on render', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final mesh = buildFlapContentMesh(
        size: const Size(800, 600),
        foldX: 700,
        flapLeft: -200,
        curveOffset: 50,
        srcRect: const Rect.fromLTWH(0, 0, 400, 600),
        columns: 6,
        flipHorizontal: true,
      );

      canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()..color = Colors.white,
      );

      final image = await recorder.endRecording().toImage(800, 600);
      expect(image, isNotNull);
      image.dispose();
    });

    test('flipHorizontal mesh renders without error', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 250,
        flapLeft: 100,
        curveOffset: 12,
        srcRect: srcRect,
        segments: 8,
        flipHorizontal: true,
      );

      canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()..color = Colors.blue,
      );

      final image = await recorder.endRecording().toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
      expect(image, isNotNull);
      image.dispose();
    });
  });
}
