import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart'
    show PageFlipOpenClipper;
import 'package:real_page_flip/src/page_flip_layer_view.dart'
    show PageFlipLayerView;

/// Strategy object that encapsulates 4-mode (single/double × forward/backward)
/// layer content allocation for the page flip compositing stack.
///
/// Extracted from [PageFlipLayerView]'s nested if/else to make each mode's
/// behavior independently testable and auditable.
///
/// ## Layer roles
///
/// | Layer | What it shows |
/// |-------|--------------|
/// | Bottom | Content revealed behind the fold |
/// | Middle | Stationary content under the flap |
/// | Flap | Shadow/highlight effect (not covered here) |
///
/// ## Modes
///
/// | Mode | Bottom | Middle |
/// |------|--------|--------|
/// | Single forward | Next page | Current page |
/// | Single backward | Current page | Previous page |
/// | Double forward | Next spread right half | Full current spread |
/// | Double backward | Previous spread left half | Full current spread |
class FlipLayerPolicy {
  const FlipLayerPolicy({
    required this.isDoubleSpread,
    required this.isForward,
    required this.currentIndex,
    required this.itemCount,
  });

  /// Whether the book is in double-spread mode (two pages per viewport).
  final bool isDoubleSpread;

  /// True when dragging forward (next page), false for backward (previous page).
  final bool isForward;

  /// The currently visible page/spread index.
  final int currentIndex;

  /// Total number of pages/spreads.
  final int itemCount;

  // ─── Bottom layer (revealed behind the fold) ───

  /// Spread half to show in the bottom layer (double mode), or null.
  ///
  /// Null means the bottom layer should fall back to opaque paper
  /// (out-of-bounds or single mode).
  ({int index, Alignment alignment})? get bottomSpreadHalf {
    if (!isDoubleSpread) return null;
    if (isForward) {
      // Forward: reveal the NEXT spread's RIGHT half behind the fold
      if (currentIndex < itemCount - 1) {
        return (index: currentIndex + 1, alignment: Alignment.centerRight);
      }
      return null; // paper fallback on last spread
    }
    // Backward: reveal the PREV spread's LEFT half behind the fold
    if (currentIndex > 0) {
      return (index: currentIndex - 1, alignment: Alignment.centerLeft);
    }
    return null; // paper fallback
  }

  /// Full page/spread index for the bottom layer (single mode), or null for paper.
  int? get bottomPageIndex {
    if (isDoubleSpread) return null; // uses spread half instead
    if (isForward) {
      return currentIndex < itemCount - 1 ? currentIndex + 1 : null;
    }
    // Backward single: bottom shows the underside of the current page
    return currentIndex;
  }

  // ─── Middle layer (stationary under the flap) ───

  /// Full spread index for the middle layer (double mode), or null for single mode.
  ///
  /// In double mode the entire current spread sits stationary under the flap
  /// (half of it may be clipped by [PageFlipOpenClipper] in backward mode).
  int? get middleSpreadIndex => isDoubleSpread ? currentIndex : null;

  /// Page index for the middle layer (single backward mode), or null for paper.
  ///
  /// In single forward mode the middle layer is opaque paper (the current page
  /// rides in the flap layer). In single backward mode the previous page peels
  /// in from the left edge.
  int? get middlePageIndex {
    if (isDoubleSpread) return null; // uses full spread
    if (isForward) {
      return currentIndex; // current page stays visible on stationary side
    }
    return currentIndex > 0 ? currentIndex - 1 : null;
  }

  // ─── Flap front texture snapshot ───

  int? get flapSnapshotSpreadIndex {
    if (!isDoubleSpread && !isForward) {
      return currentIndex > 0 ? currentIndex - 1 : null;
    }
    if (!isDoubleSpread) return currentIndex;
    if (isForward) {
      return currentIndex < itemCount - 1 ? currentIndex + 1 : null;
    }
    return currentIndex > 0 ? currentIndex - 1 : null;
  }

  /// Spread index whose snapshot provides the settle-phase flap front content.
  ///
  /// During Phase 3 (settle, progress 0.85-0.95) the flap re-displays content
  /// from the **destination** page rather than the page being peeled:
  /// - Forward double: next spread (destination on the right).
  /// - Backward double: previous spread (destination on the left).
  /// - Single mode: delegates to [flapSnapshotSpreadIndex] (no change).
  ///
  /// Returns null at book boundaries where the destination does not exist.
  int? get flapSettleSnapshotSpreadIndex {
    if (!isDoubleSpread) {
      return flapSnapshotSpreadIndex;
    }
    return flapSnapshotSpreadIndex;
  }
}
