/// A high-fidelity, physics-based page flip animation engine for Flutter.
///
/// This package provides PageFlipWidget which models real-world paper
/// friction, resistance, and dynamic shadows.
library real_page_flip;

export 'src/controllers/page_flip_state_controller.dart' show PageFlipEvent;
export 'src/models/page_flip_config.dart'
    show PageFlipConfig, PageFlipSpreadMode, PageFlipSpreadModeCompat;
export 'src/models/page_flip_effect_handler.dart';
export 'src/models/paper_texture_preset.dart';
export 'src/page_flip_widget.dart';
export 'src/physics/paper_physics.dart' show PaperPhysicsEngine;
export 'src/physics/paper_physics_config.dart' show PaperPhysicsConfig;
export 'src/physics/paper_physics_frame.dart' show PaperPhysicsFrame;
export 'src/widgets/default_page_flip_effect_handler.dart'
    show DefaultPageFlipEffectHandler;
export 'src/effects/page_flip_engine.dart' show clipSpreadPageHalf;
