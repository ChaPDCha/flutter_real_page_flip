import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Manages pre-rendering of adjacent pages to improve flip performance.
class PreRenderManager {
  /// Creates a new pre-render manager instance.
  PreRenderManager();

  /// Repository of global keys used to identify repaint boundaries.
  final Map<int, GlobalKey> pageKeys = {};

  /// Repository of captured [ui.Image] snapshots ready for layered rendering.
  final Map<int, ui.Image> pageSnapshots = {};

  /// Removes cached keys and snapshots that are outside the current [currentIndex] window.
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

  /// Completely flushes all caches and active timers.
  void reset() {
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }

  /// Initializes [GlobalKey]s for the current and immediate neighboring pages.
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

  /// Asynchronously captures rasterized [ui.Image] snapshots of adjacent pages.
  /// Uses a debounce [delay] to avoid capturing during active animations.
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

  /// Immediately disposes all cached image snapshots to free memory.
  void flushSnapshots() {
    if (pageSnapshots.isEmpty) return;
    for (final image in pageSnapshots.values) {
      image.dispose();
    }
    pageSnapshots.clear();
  }

  /// Cancels any pending debounced snapshot capture operations.
  void cancelPreRender() {
    _debounceTimer?.cancel();
  }

  /// Permanently disposes the manager and all its resources.
  void dispose() {
    _isDisposed = true;
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }
}
