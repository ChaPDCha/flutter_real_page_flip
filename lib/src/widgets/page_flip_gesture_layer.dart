import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

/// Transparent overlay that owns horizontal page-flip drags above page content.
///
/// Uses a top-level [Listener] so horizontal flips are decided from raw pointer
/// events before the gesture arena. [SelectableText] and reader wrappers cannot
/// steal the drag once [PageFlipGestureArbitration] accepts flip intent.
class PageFlipGestureLayer extends StatefulWidget {
  /// Creates a full-size gesture capture layer.
  const PageFlipGestureLayer({
    required this.controller,
    required this.sensitivity,
    required this.totalPages,
    super.key,
  });

  /// Flip state driven by drag callbacks.
  final PageFlipStateController controller;

  /// Drag sensitivity (0.0–1.0), same as [PageFlipConfig.sensitivity].
  final double sensitivity;

  /// Total pages for boundary checks.
  final int totalPages;

  @override
  State<PageFlipGestureLayer> createState() => _PageFlipGestureLayerState();
}

class _PageFlipGestureLayerState extends State<PageFlipGestureLayer> {
  int? _activePointer;
  double _totalDx = 0;
  double _totalDy = 0;
  bool _flipActive = false;
  VelocityTracker? _velocityTracker;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: const SizedBox.expand(),
      );

  Offset _localPosition(Offset global) {
    if (!mounted) return global;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return global;
    return box.globalToLocal(global);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!mounted) return;
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _totalDx = 0;
    _totalDy = 0;
    _flipActive = false;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!mounted) return;
    if (event.pointer != _activePointer) return;

    _totalDx += event.delta.dx;
    _totalDy += event.delta.dy;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final local = _localPosition(event.position);

    if (!_flipActive) {
      if (!PageFlipGestureArbitration.shouldAcceptFlipDrag(
        totalDx: _totalDx,
        totalDy: _totalDy,
        sensitivity: widget.sensitivity,
      )) {
        return;
      }
      _flipActive = true;
      widget.controller.beginPointerCapture();
      widget.controller.onDragStart(
        DragStartDetails(
          globalPosition: event.position,
          localPosition: local,
        ),
        widget.totalPages,
        accumulatedTotalDx: _totalDx,
      );
    }

    // After flip is active, continuously monitor whether the gesture has
    // become predominantly vertical (e.g. user started scrolling page content).
    // If so, cancel the flip so scrollable content beneath can respond.
    if (PageFlipGestureArbitration.shouldYieldToContent(
      totalDx: _totalDx,
      totalDy: _totalDy,
      sensitivity: widget.sensitivity,
    )) {
      _finishPointer(event.pointer, canceled: true);
      return;
    }

    widget.controller.onDragUpdate(
      DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        primaryDelta: _axisAlignedPrimaryDelta(event.delta),
        globalPosition: event.position,
        localPosition: local,
      ),
      widget.totalPages,
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!mounted) return;
    _finishPointer(event.pointer, canceled: false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!mounted) return;
    _finishPointer(event.pointer, canceled: true);
  }

  void _finishPointer(int pointer, {required bool canceled}) {
    if (!mounted) return;
    if (pointer != _activePointer) return;

    if (_flipActive) {
      if (canceled) {
        widget.controller.onDragCancel(widget.totalPages);
      } else {
        final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
        widget.controller.onDragEnd(
          DragEndDetails(
            primaryVelocity:
                _axisAlignedPrimaryVelocity(velocity.pixelsPerSecond),
            velocity: velocity,
          ),
          widget.totalPages,
        );
      }
      widget.controller.endPointerCapture();
    }

    _activePointer = null;
    _flipActive = false;
    _totalDx = 0;
    _totalDy = 0;
    _velocityTracker = null;
  }
}

/// [DragUpdateDetails.primaryDelta] must be null or match a single axis of [delta].
double? _axisAlignedPrimaryDelta(Offset delta) {
  if (delta.dy == 0.0) return delta.dx;
  if (delta.dx == 0.0) return delta.dy;
  return null;
}

/// [DragEndDetails.primaryVelocity] must be null or match a single axis of velocity.
double? _axisAlignedPrimaryVelocity(Offset pixelsPerSecond) {
  if (pixelsPerSecond.dy == 0.0) return pixelsPerSecond.dx;
  if (pixelsPerSecond.dx == 0.0) return pixelsPerSecond.dy;
  return null;
}
