import 'dart:async';

import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

/// Interface for handling effects triggered by the PageFlip engine.
/// This allows the core engine to remain generic and dependency-free,
/// while allowing for sophisticated haptic and audio implementations.
abstract class PageFlipEffectHandler {
  /// Called when an effect is triggered by the engine.
  /// Returns [FutureOr] so that async implementations (e.g. audio playback,
  /// physics-based haptics) are supported without forcing all callers to await.
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  });

  /// Updates the viewport width so haptic physics normalize correctly.
  /// Called during widget layout when the available width changes.
  /// Default no-op for custom handlers that don't need width normalization.
  set viewportWidth(double width) {}

  /// Dispose any resources (audio players, etc.) used by the handler.
  void dispose();
}
