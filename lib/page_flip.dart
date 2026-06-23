/// Legacy library for the real_page_flip package.
///
/// Provides PageFlipWidget and PageFlipEvent for programmatic page flip
/// control. Prefer importing `package:real_page_flip/real_page_flip.dart`.
library page_flip;

// State controller for programmatic control
export 'src/controllers/page_flip_state_controller.dart' show PageFlipEvent;
export 'src/page_flip_widget.dart';
