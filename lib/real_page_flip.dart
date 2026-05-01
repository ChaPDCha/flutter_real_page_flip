/// A high-fidelity, physics-based page flip animation engine for Flutter.
///
/// This package provides [PageFlipWidget] which models real-world paper
/// friction, resistance, and dynamic shadows.
library real_page_flip;

export 'src/page_flip_widget.dart';
export 'src/models/page_flip_config.dart';
export 'src/models/page_flip_effect_handler.dart';
export 'src/physics/paper_physics_config.dart';
export 'src/physics/paper_physics.dart';
export 'src/physics/paper_physics_frame.dart';
export 'src/physics/stick_slip_controller.dart'
    show StickSlipEvent, StickSlipEventType;
export 'src/controllers/page_flip_state_controller.dart' show PageFlipEvent;
