import 'package:flutter/material.dart';

/// Edge tap feedback widget for intuitive page navigation.
///
/// - Provides immediate visual feedback on tap-down.
/// - Cancels feedback when a drag gesture takes over (onTapCancel).
/// - Adapts gradient to the current theme (dark/light mode).
class EdgeTapFeedback extends StatefulWidget {
  /// Creates an [EdgeTapFeedback] widget for the given edge.
  const EdgeTapFeedback({
    /// Callback invoked when the edge tap area is tapped.
    required this.onTap, /// Whether this is the left edge (true) or right edge (false).
    required this.isLeftEdge, /// The width of the tap area in pixels.
    required this.width, super.key,

    /// Accessibility label for the edge tap area.
    this.label,

    /// Accessibility hint for the edge tap area.
    this.hint,
  });

  /// Callback invoked when the edge tap area is tapped.
  final VoidCallback onTap;

  /// Whether this is the left edge (true) or right edge (false).
  final bool isLeftEdge;

  /// The width of the tap area in pixels.
  final double width;

  /// Accessibility label for the edge tap area.
  final String? label;

  /// Accessibility hint for the edge tap area.
  final String? hint;

  @override
  State<EdgeTapFeedback> createState() => _EdgeTapFeedbackState();
}

class _EdgeTapFeedbackState extends State<EdgeTapFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // In: 50ms (매우 빠름), Out: 250ms (부드럽게)
    _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        reverseDuration: const Duration(milliseconds: 50),);

    // Decelerate 커브로 자연스러운 감속 효과
    _opacityAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    // 터치 즉시 피드백 표시 (Fast In)
    _controller.reverseDuration = const Duration(milliseconds: 50);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    // 액션 수행 및 부드럽게 사라짐 (Slow Out)
    widget.onTap();
    _fadeOut();
  }

  void _handleTapCancel() {
    // 드래그 등으로 취소 시 부드럽게 사라짐
    _fadeOut();
  }

  void _fadeOut() {
    _controller.duration = const Duration(milliseconds: 250);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 다크모드에서는 흰색 글로우, 라이트모드에서는 검은색 그림자 느낌
    final baseColor = isDark ? Colors.white : Colors.black;

    return Positioned(
      left: widget.isLeftEdge ? 0 : null,
      right: widget.isLeftEdge ? null : 0,
      top: 0,
      bottom: 0,
      width: widget.width,
      child: Semantics(
        label: widget.label,
        hint: widget.hint,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent, // 터치 통과 및 감지
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: AnimatedBuilder(
            animation: _opacityAnimation,
            builder: (context, child) {
              // 그라데이션: 가장자리(진함) -> 안쪽(투명)
              // 평상시에도 아주 희미한 힌트(0.02)를 남기고, 터치 시 더 명확하게(0.20) 표시
              final currentOpacity = (_opacityAnimation.value * 0.18) + 0.02;

              final gradientColors = [
                baseColor.withValues(alpha: currentOpacity),
                baseColor.withValues(alpha: 0),
              ];

              final gradient = LinearGradient(
                begin: widget.isLeftEdge
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                end: widget.isLeftEdge
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                colors: gradientColors,
              );

              return Container(
                decoration: BoxDecoration(gradient: gradient),
              );
            },
          ),
        ),
      ),
    );
  }
}
