import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Manages pre-rendering of adjacent pages to improve flip performance.
class PreRenderManager {
  /// GlobalKeys for tracking rendered pages.
  final Map<int, GlobalKey> pageKeys = {};

  /// Cached snapshots (ui.Image) of pre-rendered adjacent pages.
  final Map<int, ui.Image> pageSnapshots = {};

  /// Cached snapshots of the current spread (used for flap front texture).
  final Map<int, ui.Image> spreadSnapshots = {};

  /// Returns indices to capture for the given [currentIndex].
  ///
  /// When [includeCurrent] is true, the current spread index is included
  /// (needed for flap front texture during flip animation).
  @visibleForTesting
  List<int> getCaptureIndices(
    int currentIndex,
    int totalPages, {
    bool includeCurrent = false,
  }) {
    final indices = <int>[];
    if (currentIndex > 0) indices.add(currentIndex - 1);
    if (includeCurrent) indices.add(currentIndex);
    if (currentIndex < totalPages - 1) indices.add(currentIndex + 1);
    return indices;
  }

  /// Indices captured as full spread snapshots (current + previous for backward flap).
  ///
  /// Host contract (double-spread mode):
  /// - Each index is one two-page spread; itemBuilder must paint left+right pages.
  /// - Call captureSnapshots with includeCurrentSpread: true before/during flips
  ///   so spreadSnapshots contains currentIndex ± 1 for spine reveal and flap texture.
  @visibleForTesting
  List<int> getSpreadCaptureIndices(
    int currentIndex,
    int totalPages, {
    bool includeCurrent = false,
  }) {
    if (!includeCurrent) return const [];
    final indices = <int>[];
    if (currentIndex > 0) indices.add(currentIndex - 1);
    indices.add(currentIndex);
    if (currentIndex < totalPages - 1) indices.add(currentIndex + 1);
    return indices;
  }

  /// Removes snapshots and keys for pages that are no longer adjacent.
  void cleanup(int currentIndex, int totalPages) {
    final targetIndices = getCaptureIndices(currentIndex, totalPages, includeCurrent: true);
    final toDispose = <ui.Image>{};

    pageSnapshots.removeWhere((index, image) {
      if (!targetIndices.contains(index) && index != currentIndex) {
        toDispose.add(image);
        return true;
      }
      return false;
    });

    spreadSnapshots.removeWhere((index, image) {
      if (!targetIndices.contains(index)) {
        toDispose.add(image);
        return true;
      }
      return false;
    });

    _disposeImagesOnce(toDispose);

    pageKeys.removeWhere(
      (index, _) => !targetIndices.contains(index) && index != currentIndex,
    );
  }

  void _disposeImagesOnce(Set<ui.Image> images) {
    for (final image in images) {
      image.dispose();
    }
  }

  /// Resets the manager: cancels pending renders, clears snapshots and keys.
  void reset() {
    _captureGeneration++; // Cancel any running async captures
    _retryScheduled = false;
    _retryCurrentIndex = null;
    _retryTotalPages = null;
    _retryOnCaptured = null;
    _retryPixelRatio = 1;
    _activeCaptures.clear();
    _pendingRetryIndices.clear();
    _captureRetryCounts.clear();
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }

  /// Ensures that keys exist for the current page and adjacent pages.
  void prepareKeys(int currentIndex, int totalPages) {
    // Ensure current index always has a key
    pageKeys.putIfAbsent(currentIndex, GlobalKey.new);

    final targetIndices = getCaptureIndices(currentIndex, totalPages, includeCurrent: true);
    for (final index in targetIndices) {
      pageKeys.putIfAbsent(index, GlobalKey.new);
    }
  }

  Timer? _debounceTimer;
  bool _isDisposed = false;

  /// Current generation token to prevent outdated asynchronous capture operations
  /// from overwriting newer snapshots or leaking memory.
  int _captureGeneration = 0;

  /// Set of indices currently being captured to prevent redundant overlapping captures.
  final Set<int> _activeCaptures = {};

  /// Indices waiting for a post-frame retry (layout not ready yet).
  final Set<int> _pendingRetryIndices = {};

  /// Post-frame callback token for batched capture retries.
  bool _retryScheduled = false;

  /// Last capture context used to retry pending indices.
  int? _retryCurrentIndex;
  int? _retryTotalPages;
  VoidCallback? _retryOnCaptured;
  int _retryGeneration = 0;
  bool _retryIncludeCurrentSpread = false;
  double _retryPixelRatio = 1;

  static const int _maxCaptureRetriesPerIndex = 12;
  final Map<int, int> _captureRetryCounts = {};

  /// Returns true if a snapshot has been captured for the given [index].
  bool hasSnapshot(int index) => pageSnapshots.containsKey(index);

  /// Returns true if a spread snapshot exists for the given [index].
  bool hasSpreadSnapshot(int index) => spreadSnapshots.containsKey(index);

  /// True when [index] is queued or actively being captured.
  @visibleForTesting
  bool isCapturePending(int index) =>
      _activeCaptures.contains(index) || _pendingRetryIndices.contains(index);

  /// Returns true when every adjacent snapshot needed for a flip is cached.
  bool hasAdjacentSnapshots(
    int currentIndex,
    int totalPages, {
    bool includeCurrentSpread = false,
  }) {
    final targetIndices = getCaptureIndices(
      currentIndex,
      totalPages,
      includeCurrent: includeCurrentSpread,
    );
    final spreadIndices = getSpreadCaptureIndices(
      currentIndex,
      totalPages,
      includeCurrent: includeCurrentSpread,
    );

    for (final index in targetIndices) {
      if (spreadIndices.contains(index)) {
        if (!spreadSnapshots.containsKey(index)) return false;
      } else if (!pageSnapshots.containsKey(index)) {
        return false;
      }
    }
    return true;
  }

  /// Captures snapshots of adjacent pages for smooth flip transitions.
  ///
  /// When [immediate] is true, the debounce timer is skipped and capture
  /// happens on the next microtask. Use this after page changes or at flip
  /// start to ensure snapshots are available before animation frames.
  Future<void> captureSnapshots(
    int currentIndex,
    int totalPages,
    VoidCallback onSnapshotCaptured, {
    Duration delay = const Duration(milliseconds: 300),
    bool immediate = false,
    bool includeCurrentSpread = false,
    double pixelRatio = 1.0,
  }) async {
    _debounceTimer?.cancel();
    _captureGeneration++;
    final currentGen = _captureGeneration;

    if (immediate) {
      await _doCaptureSnapshots(
        currentIndex,
        totalPages,
        onSnapshotCaptured,
        currentGen,
        includeCurrentSpread: includeCurrentSpread,
        pixelRatio: pixelRatio,
      );
    } else {
      _debounceTimer = Timer(delay, () async {
        await _doCaptureSnapshots(
          currentIndex,
          totalPages,
          onSnapshotCaptured,
          currentGen,
          includeCurrentSpread: includeCurrentSpread,
          pixelRatio: pixelRatio,
        );
      });
    }
  }

  /// Core snapshot capture logic, shared by debounced and immediate paths.
  Future<void> _doCaptureSnapshots(
    int currentIndex,
    int totalPages,
    VoidCallback onSnapshotCaptured,
    int generation, {
    bool includeCurrentSpread = false,
    double pixelRatio = 1.0,
  }) async {
    if (_isDisposed || generation != _captureGeneration) return;

    final targetIndices = getCaptureIndices(
      currentIndex,
      totalPages,
      includeCurrent: includeCurrentSpread,
    );
    final spreadIndices = getSpreadCaptureIndices(
      currentIndex,
      totalPages,
      includeCurrent: includeCurrentSpread,
    );

    final toDispose = <ui.Image>{};

    for (final index in targetIndices) {
      if (_isDisposed || generation != _captureGeneration) return;

      final captureAsSpread = spreadIndices.contains(index);
      if (captureAsSpread) {
        if (spreadSnapshots.containsKey(index)) continue;
      } else if (pageSnapshots.containsKey(index)) {
        continue;
      }

      if (_activeCaptures.contains(index)) continue;
      _activeCaptures.add(index);

      final key = pageKeys[index];
      if (key == null) {
        _activeCaptures.remove(index);
        _scheduleCaptureRetry(
          index,
          currentIndex,
          totalPages,
          onSnapshotCaptured,
          generation,
          includeCurrentSpread: includeCurrentSpread,
          pixelRatio: pixelRatio,
        );
        continue;
      }

      try {
        final boundary = _findRepaintBoundary(key);
        if (boundary == null || boundary.debugNeedsPaint) {
          _activeCaptures.remove(index);
          _scheduleCaptureRetry(
            index,
            currentIndex,
            totalPages,
            onSnapshotCaptured,
            generation,
            includeCurrentSpread: includeCurrentSpread,
            pixelRatio: pixelRatio,
          );
          continue;
        }

        // Logical-pixel capture scaled by the device pixel ratio so the snapshot
        // matches the layout constraints and avoids visual sharpness Snap/Flicker.
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        _activeCaptures.remove(index);
        _captureRetryCounts.remove(index);
        _pendingRetryIndices.remove(index);

        if (_isDisposed || generation != _captureGeneration) {
          image.dispose();
          return;
        }

        if (captureAsSpread) {
          final oldImage = spreadSnapshots[index];
          spreadSnapshots[index] = image;
          if (oldImage != null) toDispose.add(oldImage);
        }
        if (!captureAsSpread || index != currentIndex) {
          final oldImage = pageSnapshots[index];
          pageSnapshots[index] = image;
          if (oldImage != null) toDispose.add(oldImage);
        }
        if (toDispose.isNotEmpty) {
          _disposeImagesOnce(toDispose);
          toDispose.clear();
        }
        onSnapshotCaptured();
      } catch (e) {
        _activeCaptures.remove(index);
        _scheduleCaptureRetry(
          index,
          currentIndex,
          totalPages,
          onSnapshotCaptured,
          generation,
          includeCurrentSpread: includeCurrentSpread,
          pixelRatio: pixelRatio,
        );
      }
    }
  }

  void _scheduleCaptureRetry(
    int index,
    int currentIndex,
    int totalPages,
    VoidCallback onSnapshotCaptured,
    int generation, {
    required bool includeCurrentSpread,
    required double pixelRatio,
  }) {
    if (_isDisposed || generation != _captureGeneration) return;

    final retries = (_captureRetryCounts[index] ?? 0) + 1;
    if (retries > _maxCaptureRetriesPerIndex) {
      _captureRetryCounts.remove(index);
      _pendingRetryIndices.remove(index);
      return;
    }
    _captureRetryCounts[index] = retries;
    _pendingRetryIndices.add(index);

    _retryCurrentIndex = currentIndex;
    _retryTotalPages = totalPages;
    _retryOnCaptured = onSnapshotCaptured;
    _retryGeneration = generation;
    _retryIncludeCurrentSpread = includeCurrentSpread;
    _retryPixelRatio = pixelRatio;

    if (_retryScheduled) return;
    _retryScheduled = true;

    // Use addPostFrameCallback so the retry runs after layout/paint is complete.
    // This ensures the boundary is fully painted (debugNeedsPaint == false),
    // allowing the capture to succeed immediately on the first retry instead of
    // looping through frame callbacks.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _retryScheduled = false;
      if (_isDisposed ||
          generation != _captureGeneration ||
          _pendingRetryIndices.isEmpty) {
        return;
      }

      final retryCurrent = _retryCurrentIndex;
      final retryTotal = _retryTotalPages;
      final retryCallback = _retryOnCaptured;
      final retryGen = _retryGeneration;
      final retryIncludeSpread = _retryIncludeCurrentSpread;
      final retryRatio = _retryPixelRatio;
      if (retryCurrent == null ||
          retryTotal == null ||
          retryCallback == null) {
        return;
      }

      await _doCaptureSnapshots(
        retryCurrent,
        retryTotal,
        retryCallback,
        retryGen,
        includeCurrentSpread: retryIncludeSpread,
        pixelRatio: retryRatio,
      );
    });
  }

  RenderRepaintBoundary? _findRepaintBoundary(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderRepaintBoundary) {
      return renderObject;
    }
    if (renderObject is RenderObject) {
      RenderRepaintBoundary? found;
      renderObject.visitChildren((child) {
        found ??= _findRepaintBoundaryInTree(child);
      });
      return found;
    }
    return null;
  }

  RenderRepaintBoundary? _findRepaintBoundaryInTree(RenderObject object) {
    if (object is RenderRepaintBoundary) return object;
    RenderRepaintBoundary? found;
    object.visitChildren((child) {
      found ??= _findRepaintBoundaryInTree(child);
    });
    return found;
  }

  /// Disposes all cached snapshots and clears the snapshot maps.
  void flushSnapshots() {
    final toDispose = <ui.Image>{}
      ..addAll(pageSnapshots.values)
      ..addAll(spreadSnapshots.values);
    pageSnapshots.clear();
    spreadSnapshots.clear();
    _disposeImagesOnce(toDispose);
  }

  /// Cancels any pending pre-render timer.
  void cancelPreRender() {
    _debounceTimer?.cancel();
  }

  /// Disposes the manager: cancels renders, disposes all snapshots.
  void dispose() {
    _isDisposed = true;
    _captureGeneration++;
    _retryScheduled = false;
    _retryCurrentIndex = null;
    _retryTotalPages = null;
    _retryOnCaptured = null;
    _retryPixelRatio = 1;
    _activeCaptures.clear();
    _pendingRetryIndices.clear();
    _captureRetryCounts.clear();
    cancelPreRender();
    flushSnapshots();
    pageKeys.clear();
  }
}
