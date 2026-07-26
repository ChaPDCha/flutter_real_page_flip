/// Page flip engine — barrel + flap content mesh, widget helpers.
///
/// Re-exports:
/// - `page_flip_path_builders.dart` — curve math, clip paths, shadow meshes
/// - `page_flip_texture_rects.dart` — flap texture source rects
/// - `page_flip_shading.dart` — highlight/shadow tones, opacity curves
/// - `page_flip_clippers.dart` — spread clipper widgets
/// - `page_flip_painter.dart` — [PageFlipPainter]
/// - `page_flip_geometry.dart` — [PageFlipGeometry], animation constants
/// - `page_flip_gesture.dart` — [PageFlipGestureRecognizer]
/// - `page_flip_constants.dart` — numeric constants
///
/// Remaining in this file:
/// - [buildFlapContentMesh] + mesh density helper
/// - Widget helpers (clip, snapshot display)
/// - [flipSideShadowClipRect]
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/effects/page_flip_clippers.dart';
export 'package:real_page_flip/src/effects/page_flip_clippers.dart';
import 'package:real_page_flip/src/effects/page_flip_constants.dart';
export 'package:real_page_flip/src/effects/page_flip_constants.dart';
import 'package:real_page_flip/src/effects/page_flip_geometry.dart';
export 'package:real_page_flip/src/effects/page_flip_geometry.dart';
import 'package:real_page_flip/src/effects/page_flip_gesture.dart';
export 'package:real_page_flip/src/effects/page_flip_gesture.dart';
import 'package:real_page_flip/src/effects/page_flip_painter.dart';
export 'package:real_page_flip/src/effects/page_flip_painter.dart';
import 'package:real_page_flip/src/effects/page_flip_path_builders.dart';
export 'package:real_page_flip/src/effects/page_flip_path_builders.dart';
export 'package:real_page_flip/src/effects/page_flip_shading.dart';
import 'package:real_page_flip/src/effects/page_flip_texture_rects.dart';
export 'package:real_page_flip/src/effects/page_flip_texture_rects.dart';

// Path builders, curve math, clip paths, and shadow meshes are in
// page_flip_path_builders.dart (re-exported above).
//
// Remaining in this file: flap content mesh, widget helpers, shadow clip rect.



({int segments, int columns}) flapMeshDensityForPerformance(
  DevicePerformanceProfile profile,
) =>
    switch (profile) {
      DevicePerformanceProfile.low => (segments: 8, columns: 1),
      DevicePerformanceProfile.medium => (segments: 12, columns: 2),
      DevicePerformanceProfile.high => (segments: 16, columns: 4),
    };

/// Builds a triangle mesh that curves the flap texture along the fold and
/// flap-edge bezier curves so text and images bend with the paper.
///
/// Without this mesh, the flap content is drawn as a flat rectangle (affine
/// transform only) and looks like a flat board tilting rather than paper
/// curling. The mesh follows the quadratic bezier of both the fold line
/// and the flap edge, so every scanline maps to the correct curved position.
///
/// With [columns] >= 1, interior vertex columns are added between the fold
/// and flap edge. Each interior column has an amplified bezier offset (bulge)
/// that peaks at the midpoint, creating a convex 3D surface curvature effect.
/// Without this bulge the surface is a flat ruled plane between two curves -
/// text appears stiff rather than printed on curling paper.
///
/// [segments] vertical subdivisions (higher = smoother, default 16).
/// [columns] horizontal subdivisions (0 = fold-to-flap only, 4+ recommended).
ui.Vertices buildFlapContentMesh({
  required Size size,
  required double foldX,
  required double flapLeft,
  required double curveOffset,
  required Rect srcRect,
  int segments = 16,
  int columns = 4,
  bool flipHorizontal = false,
}) {
  final safeSegments = math.max(segments, 0);
  final safeColumns = math.max(columns, 0);
  if (safeSegments == 0 || size.height <= 0 || srcRect.isEmpty) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List(0),
      textureCoordinates: Float32List(0),
    );
  }

  final height = size.height;
  final totalCols = safeColumns + 2; // fold + interior + flap edge columns
  final rows = safeSegments + 1;
  final vertexCount = rows * totalCols;
  if (vertexCount > 0x10000) {
    throw ArgumentError.value(
      vertexCount,
      'segments/columns',
      'Flap mesh exceeds Uint16 index capacity',
    );
  }

  // -----------------------------------------------------------------------
  // 1. Build vertex grid [rows] × [totalCols] in a flat array.
  //
  // Store each grid point once, then reference it from Uint16 indices below.
  // At the default density this keeps 102 positions/UVs instead of expanding
  // the same coordinates into 160 duplicated triangle vertices per mesh.
  //
  //   fold  col1  col2  col3  col4  flap
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row 0 (top)
  //    │╲    │     │     │     │    ╱│
  //    │ ╲   │     │ ╶───→│     │   ╱ │   bulge peak (more left shift)
  //    │  ╲  │     │     │     │  ╱  │
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row N (bottom)
  // -----------------------------------------------------------------------
  final positions = Float32List(vertexCount * 2);
  final texCoords = Float32List(vertexCount * 2);

  // Surface bulge factor: how much extra curvature interior columns get.
  // 30% additional bezier offset at the midpoint column creates visible
  // 3D curvature without looking like tightly rolled paper.
  const kBulgeStrength = 0.30;
  final colScale = 1.0 / (totalCols - 1);

  for (var i = 0; i < rows; i++) {
    final t = i / safeSegments;
    final y = height * t;
    // Use the same extended vertical domain as the screen clip. UVs still use
    // the visible 0..1 [t] below; only the projected paper position is curved.
    final b = flapCurveBlendAt(y, height);
    final rowBase = i * totalCols;

    for (var j = 0; j < totalCols; j++) {
      final s = j * colScale; // 0 at fold, 1 at flap edge

      // Interior columns get amplified bezier offset → surface bulge.
      // sin(s*pi) peaks at s=0.5 and is zero at both edges, so the bulge
      // smoothly blends to the existing fold/flap edge positions.
      final bulgeScale = safeColumns > 0 ? math.sin(s * math.pi) : 0.0;
      final colCurveScale = 1.0 + kBulgeStrength * bulgeScale;
      final colOffset = curveOffset * colCurveScale;

      // Column bezier-fold position at this row.
      final foldAtY = foldX - colOffset * b;
      final flapAtY = flapLeft - colOffset * b;

      final idx = rowBase + j;
      final coord = idx * 2;
      // Interpolate X between fold and flap edge for this column.
      positions[coord] = foldAtY + (flapAtY - foldAtY) * s;
      positions[coord + 1] = y;
      // UV: right→left from srcRect.right (fold) to srcRect.left (flap edge).
      // flipHorizontal for mirrored 2.5D back content on double-spread.
      texCoords[coord] = flipHorizontal
          ? srcRect.left + s * srcRect.width
          : srcRect.right - s * srcRect.width;
      texCoords[coord + 1] = srcRect.top + t * srcRect.height;
    }
  }

  // -----------------------------------------------------------------------
  // 2. Triangle pairs from the vertex grid (2 triangles per quad).
  //
  //  (i,j) ─── (i,j+1)
  //    | ╲     |
  //    |  ╲    |
  //  (i+1,j) ─ (i+1,j+1)
  //
  // T1: (i,j), (i+1,j), (i,j+1)
  // T2: (i,j+1), (i+1,j), (i+1,j+1)
  //
  // Indexed vertices keep each grid point once and reference it from triangle
  // pairs. This preserves the exact mesh topology while avoiding duplicated
  // position/UV payload for every triangle.
  // -----------------------------------------------------------------------
  final indexCount = safeSegments * (totalCols - 1) * 6;
  final indices = Uint16List(indexCount);
  var offset = 0;

  for (var i = 0; i < safeSegments; i++) {
    final row0 = i * totalCols;
    final row1 = (i + 1) * totalCols;
    for (var j = 0; j < totalCols - 1; j++) {
      final i0j0 = row0 + j;
      final i0j1 = row0 + j + 1;
      final i1j0 = row1 + j;
      final i1j1 = row1 + j + 1;

      // Triangle 1: (i,j), (i+1,j), (i,j+1)
      indices[offset++] = i0j0;
      indices[offset++] = i1j0;
      indices[offset++] = i0j1;

      // Triangle 2: (i,j+1), (i+1,j), (i+1,j+1)
      indices[offset++] = i0j1;
      indices[offset++] = i1j0;
      indices[offset++] = i1j1;
    }
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    textureCoordinates: texCoords,
    indices: indices,
  );
}

/// Clip rect for flap-side drop shadows in [PageFlipPainter].
///
/// Double-spread: the active turning half. Single-page: the side of the fold
/// occupied by the turning flap.
Rect flipSideShadowClipRect(PageFlipGeometry geo) {
  if (geo.isDoubleSpread) {
    return geo.isForward
        ? Rect.fromLTWH(
            geo.spineX,
            0,
            geo.size.width - geo.spineX,
            geo.size.height,
          )
        : Rect.fromLTWH(0, 0, geo.spineX, geo.size.height);
  }
  final fold = geo.foldX.clamp(0.0, geo.size.width);
  if (geo.flapRightOfFold) {
    return Rect.fromLTWH(0, 0, fold, geo.size.height);
  }
  return Rect.fromLTWH(fold, 0, geo.size.width - fold, geo.size.height);
}

/// Clips [child] to the left or right half when [child] already spans the
/// full viewport-sized spread (snapshot or live two-page layout).
///
/// Use this in `PageFlipLayerView` flip layers. Do **not** pair with
/// [FractionallySizedBox] — that would double horizontal scale and stretch
/// spread snapshots via [BoxFit.fill].
Widget clipFullSpreadHalf({
  required Widget child,
  required Alignment alignment,
}) =>
    ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.5,
        child: child,
      ),
    );

/// Clips [child] to the left or right half when [child] lives in a **half-width**
/// slot (e.g. [Expanded] in a [Row]) and must be expanded to full spread width
/// before clipping — typical host `itemBuilder` layouts.
Widget clipSpreadPageHalf({
  required Widget child,
  required Alignment alignment,
}) =>
    ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.5,
        child: FractionallySizedBox(
          widthFactor: 2,
          alignment: alignment,
          child: child,
        ),
      ),
    );

/// Displays a pre-render snapshot at [viewportSize] without aspect distortion.
///
/// Snapshots are captured at logical viewport dimensions; [BoxFit.fill] in a
/// matching [SizedBox] preserves proportions identical to the idle live page.
Widget buildViewportSnapshotImage(
  ui.Image image, {
  required Size viewportSize,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) {
    return RawImage(image: image, fit: BoxFit.fill);
  }
  return SizedBox(
    width: viewportSize.width,
    height: viewportSize.height,
    child: RawImage(
      image: image,
      fit: BoxFit.fill,
    ),
  );
}

