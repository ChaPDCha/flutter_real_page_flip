import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

/// Routes raw pointer events to [PageFlipStateController] without competing
/// in the gesture arena (e.g. with [SelectableText] horizontal selection).
class PageFlipPointerHandler {
  /// Creates a handler for the given controller and page count.
  PageFlipPointerHandler({
    required this.controller,
    required this.sensitivity,
    required this.totalPages,
  });

  /// Flip state updated by pointer drags.
  final PageFlipStateController controller;

  /// Drag sensitivity (0.0–1.0), same as [PageFlipConfig.sensitivity].
  double sensitivity;

  /// Total pages for boundary checks.
  int totalPages;

  double _totalDx = 0;
  double _totalDy = 0;
  int? _activePointer;
  bool _flipGestureActive = false;
  VelocityTracker? _velocityTracker;

  void handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;

    _activePointer = event.pointer;
    _totalDx = 0;
    _totalDy = 0;
    _flipGestureActive = false;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;

    _totalDx += event.delta.dx;
    _totalDy += event.delta.dy;
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    if (!_flipGestureActive) {
      if (!PageFlipGestureArbitration.shouldAcceptFlipDrag(
        totalDx: _totalDx,
        totalDy: _totalDy,
        sensitivity: sensitivity,
      )) {
        return;
      }
      _flipGestureActive = true;
      controller.onDragStart(
        DragStartDetails(
          localPosition: event.localPosition,
          globalPosition: event.position,
        ),
        totalPages,
      );
    }

    controller.onDragUpdate(
      DragUpdateDetails(
        localPosition: event.localPosition,
        globalPosition: event.position,
        delta: event.delta,
        primaryDelta: event.delta.dx,
      ),
      totalPages,
    );
  }

  void handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;

    if (_flipGestureActive) {
      final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
      controller.onDragEnd(
        DragEndDetails(
          velocity: velocity,
          primaryVelocity: velocity.pixelsPerSecond.dx,
        ),
        totalPages,
      );
    }
    _reset();
  }

  void handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;

    if (_flipGestureActive) {
      controller.onDragCancel(totalPages);
    }
    _reset();
  }

  void _reset() {
    _activePointer = null;
    _flipGestureActive = false;
    _velocityTracker = null;
    _totalDx = 0;
    _totalDy = 0;
  }
}
