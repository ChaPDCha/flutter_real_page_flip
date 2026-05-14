import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Manages pre-rendering of adjacent pages to improve flip performance.
class PreRenderManager {
  /// GlobalKeys for tracking rendered pages.
  final Map<int, GlobalKey> pageKeys = {};

  /// Cached snapshots (ui.Image) of pre-rendered pages.
  final Map<int, ui.Image> pageSnapshots = {};

  /// Removes snapshots and keys for pages that are no longer adjacent.
  void cleanup(int currentIndex, int totalPages) {
    final targetIndices = _getTargetIndices(currentIndex, totalPages);

    // Remove unused snapshots
    pageSnapshots.removeWhere((index, image) {
      if (!targetIndices.contains(index) && index != currentIndex) {
        image.dispose();
        return true;
      }
      return false;
    });

    // Remove unused keys
    pageKeys.removeWhere(
      (index, _) => !targetIndices.contains(index) && index != currentIndex,
    );
  }

  /// Resets the manager: cancels pending renders, clears snapshots and keys.
  void reset() {
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }

  /// Ensures that keys exist for the current page and adjacent pages.
  void prepareKeys(int currentIndex, int totalPages) {
    // Ensure current index always has a key
    pageKeys.putIfAbsent(currentIndex, GlobalKey.new);

    final targetIndices = _getTargetIndices(currentIndex, totalPages);
    for (final index in targetIndices) {
      pageKeys.putIfAbsent(index, GlobalKey.new);
    }
  }

  Timer? _debounceTimer;
  bool _isDisposed = false;

  /// Captures snapshots of adjacent pages for smooth flip transitions.
  Future<void> captureSnapshots(
    int currentIndex,
    int totalPages,
    VoidCallback onSnapshotCaptured, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    _debounceTimer?.cancel();

    // Wait for UI stabilization using a simple Timer callback
    _debounceTimer = Timer(delay, () async {
      if (_isDisposed) return;

      final targetIndices = _getTargetIndices(currentIndex, totalPages);

      for (final index in targetIndices) {
        if (_isDisposed) return;
        if (pageSnapshots.containsKey(index)) continue;

        final key = pageKeys[index];
        if (key == null) continue;

        try {
          final boundary = key.currentContext?.findRenderObject();
          if (boundary is RenderRepaintBoundary) {
            if (boundary.debugNeedsPaint) continue;

            final image = await boundary.toImage();

            if (_isDisposed) {
              image.dispose(); // Crucial: Dispose if manager died while waiting
              return;
            }

            pageSnapshots[index] = image;
            onSnapshotCaptured();
          }
        } catch (e) {
          // Ignore capture errors
        }
      }
    });
  }

  List<int> _getTargetIndices(int currentIndex, int totalPages) {
    final indices = <int>[];
    if (currentIndex > 0) indices.add(currentIndex - 1);
    if (currentIndex < totalPages - 1) indices.add(currentIndex + 1);
    return indices;
  }

  /// Disposes all cached snapshots and clears the snapshot map.
  void flushSnapshots() {
    if (pageSnapshots.isEmpty) return;
    for (final image in pageSnapshots.values) {
      image.dispose();
    }
    pageSnapshots.clear();
  }

  /// Cancels any pending pre-render timer.
  void cancelPreRender() {
    _debounceTimer?.cancel();
  }

  /// Disposes the manager: cancels renders, disposes all snapshots.
  void dispose() {
    _isDisposed = true;
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }
}
