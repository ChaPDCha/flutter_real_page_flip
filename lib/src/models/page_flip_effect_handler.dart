import '../controllers/page_flip_state_controller.dart';

/// Interface for handling effects triggered by the PageFlip engine.
/// This allows the core engine to remain generic and dependency-free,
/// while allowing for sophisticated haptic and audio implementations.
abstract class PageFlipEffectHandler {
  /// Called when an effect is triggered by the engine.
  void onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    /// The resistance factor. In the default physics implementation, 
    /// this carries the instantaneous [delta] of the movement.
    double? resistance,
  });

  /// Dispose any resources (audio players, etc.) used by the handler.
  void dispose();
}
