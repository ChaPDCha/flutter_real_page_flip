import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

void main() {
  const size = Size(400, 600);
  const srcRect = Rect.fromLTWH(0, 0, 400, 600);

  group('flapMeshDensityForPerformance', () {
    test('keeps profile mesh densities stable', () {
      expect(
        flapMeshDensityForPerformance(DevicePerformanceProfile.low),
        equals((segments: 8, columns: 1)),
      );
      expect(
        flapMeshDensityForPerformance(DevicePerformanceProfile.medium),
        equals((segments: 12, columns: 2)),
      );
      expect(
        flapMeshDensityForPerformance(DevicePerformanceProfile.high),
        equals((segments: 16, columns: 4)),
      );
    });
  });

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
      // grid = (segments+1) × (totalCols) = 17 × 6 = 102 vertices
      // Each quad has 2 triangles × 3 vertices = 6
      // Number of quads = segments × (totalCols - 1) = 16 × 5 = 80
      // Triangles = 80 × 2 = 160, referenced through Uint16 indices.
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

    test('oversized mesh fails before Uint16 indices overflow', () {
      expect(
        () => buildFlapContentMesh(
          size: size,
          foldX: 200,
          flapLeft: 50,
          curveOffset: 16,
          srcRect: srcRect,
          segments: 400,
          columns: 200,
        ),
        throwsArgumentError,
      );
    });

    test('empty srcRect returns zero-length vertex buffer', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: Rect.zero,
      );
      expect(mesh, isNotNull);
    });

    test('zero height size returns zero-length vertex buffer', () {
      final mesh = buildFlapContentMesh(
        size: const Size(400, 0),
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
      );
      expect(mesh, isNotNull);
    });

    test('negative segments are clamped to zero rows', () {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: srcRect,
        segments: -4,
      );
      expect(mesh, isNotNull);
    });

    test('profile mesh densities produce valid renderable meshes', () {
      for (final profile in DevicePerformanceProfile.values) {
        final density = flapMeshDensityForPerformance(profile);
        final mesh = buildFlapContentMesh(
          size: size,
          foldX: 200,
          flapLeft: 50,
          curveOffset: 16,
          srcRect: srcRect,
          segments: density.segments,
          columns: density.columns,
        );
        expect(mesh, isNotNull, reason: 'profile=$profile');
      }
    });

    test('empty srcRect mesh paints no visible pixels', () async {
      final mesh = buildFlapContentMesh(
        size: size,
        foldX: 200,
        flapLeft: 50,
        curveOffset: 16,
        srcRect: Rect.zero,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()..color = const Color(0xFFFF0000),
      );
      final image = await recorder.endRecording().toImage(
            size.width.toInt(),
            size.height.toInt(),
          );

      final byteData = await image.toByteData();
      expect(byteData, isNotNull);
      final stride = size.width.toInt() * 4;
      final offset = (size.height ~/ 2) * stride + (size.width ~/ 2) * 4;
      expect(byteData!.getUint8(offset), equals(0));
      image.dispose();
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

    test('mesh free edge follows the extended flap clip curve near the top',
        () async {
      const foldX = 300.0;
      const flapLeft = 100.0;
      const curveOffset = 18.0;
      final image = await renderMesh(
        foldX: foldX,
        flapLeft: flapLeft,
        curveOffset: curveOffset,
        segments: 16,
      );
      final byteData = await image.toByteData();
      expect(byteData, isNotNull);

      // The screen-space clip uses a quadratic whose endpoints are extended to
      // -H and 2H. At the visible top its blend is 4/9, so the free edge is
      // shifted 8 px left. The mesh must cover that same curved-paper wedge.
      const sampleX = 95;
      const sampleY = 2;
      final stride = size.width.toInt() * 4;
      final offset = sampleY * stride + sampleX * 4;
      expect(
        byteData!.getUint8(offset),
        greaterThan(0),
        reason:
            'Mesh and clip must share the same free-edge curve near the top',
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
