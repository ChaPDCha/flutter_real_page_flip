/// A high-fidelity, physics-based page flip animation engine for Flutter.
///
/// This package provides [PageFlipWidget] which models real-world paper
/// friction, resistance, and dynamic shadows.
library real_page_flip;

import 'package:real_page_flip/page_flip.dart' show PageFlipWidget;
import 'package:real_page_flip/real_page_flip.dart' show PageFlipWidget;
import 'package:real_page_flip/src/page_flip_widget.dart' show PageFlipWidget;

export 'src/controllers/page_flip_state_controller.dart' show PageFlipEvent;
export 'src/effects/page_flip_engine.dart'
    show clipSpreadPageHalf, kSpineRevealOverlapPx;
export 'src/models/page_flip_config.dart'
    show PageFlipConfig, PageFlipSpreadMode, PageFlipSpreadModeCompat;
export 'src/models/page_flip_effect_handler.dart';
export 'src/page_flip_widget.dart';
export 'src/physics/paper_physics.dart';
export 'src/physics/paper_physics_config.dart';
export 'src/physics/paper_physics_frame.dart';
export 'src/physics/stick_slip_controller.dart'
    show StickSlipEvent, StickSlipEventType;
