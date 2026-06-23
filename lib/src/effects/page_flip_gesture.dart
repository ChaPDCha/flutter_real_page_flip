part of 'page_flip_engine.dart';

/// Shared horizontal-vs-vertical arbitration for page-flip drags.
class PageFlipGestureArbitration {
  PageFlipGestureArbitration._();

  /// Touch slop derived from [sensitivity] (0.0–1.0).
  static double checkSlopForSensitivity(double sensitivity) =>
      18.0 - (17.0 * sensitivity);

  /// True when accumulated movement is predominantly vertical (text scroll / selection).
  static bool shouldYieldToContent({
    required double totalDx,
    required double totalDy,
    required double sensitivity,
  }) {
    final checkSlop = checkSlopForSensitivity(sensitivity);
    return totalDy.abs() > checkSlop && totalDy.abs() > totalDx.abs() * 1.2;
  }

  /// True when accumulated movement should start a page-flip drag.
  static bool shouldAcceptFlipDrag({
    required double totalDx,
    required double totalDy,
    required double sensitivity,
  }) {
    if (shouldYieldToContent(
      totalDx: totalDx,
      totalDy: totalDy,
      sensitivity: sensitivity,
    )) {
      return false;
    }

    final checkSlop = checkSlopForSensitivity(sensitivity);

    if (totalDx.abs() > checkSlop) {
      if (totalDx.abs() * 2.5 > totalDy.abs()) {
        return true;
      }
    }

    return false;
  }
}

/// A custom HorizontalDragGestureRecognizer that allows for more natural thumb arcs
/// by having a configurable sensitivity and allowing a certain amount of vertical movement.
class PageFlipGestureRecognizer extends HorizontalDragGestureRecognizer {
  /// Creates a [PageFlipGestureRecognizer] with the given sensitivity.
  PageFlipGestureRecognizer({
    super.debugOwner,

    /// Sensitivity of the gesture recognizer (0.0 to 1.0).
    /// Lower values require more horizontal movement to trigger a flip.
    this.sensitivity = 0.5,
  });

  /// Sensitivity of the gesture recognizer (0.0 to 1.0).
  final double sensitivity;
  double _totalDx = 0;
  double _totalDy = 0;
  bool _flipArenaAccepted = false;

  /// Resets accumulated deltas when a new pointer is added.
  @override
  void addAllowedPointer(PointerDownEvent event) {
    _totalDx = 0.0;
    _totalDy = 0.0;
    _flipArenaAccepted = false;
    super.addAllowedPointer(event);
  }

  @override
  void rejectGesture(int pointer) {
    _flipArenaAccepted = false;
    super.rejectGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _totalDx += event.delta.dx;
      _totalDy += event.delta.dy;
      _acceptFlipArenaWhenReady();
    }
    super.handleEvent(event);
  }

  /// Eagerly wins the arena for horizontal page-flip intent only.
  ///
  /// Vertical/content gestures are not rejected here; [hasSufficientGlobalDistanceToAccept]
  /// stays false so [SelectableText] and scrollables can win instead.
  void _acceptFlipArenaWhenReady() {
    if (_flipArenaAccepted) return;

    if (PageFlipGestureArbitration.shouldAcceptFlipDrag(
      totalDx: _totalDx,
      totalDy: _totalDy,
      sensitivity: sensitivity,
    )) {
      _flipArenaAccepted = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      PageFlipGestureArbitration.shouldAcceptFlipDrag(
        totalDx: _totalDx,
        totalDy: _totalDy,
        sensitivity: sensitivity,
      );
}
