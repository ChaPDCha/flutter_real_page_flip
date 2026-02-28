import 'package:flutter/material.dart';

/// 직관적인 페이지 넘김을 위한 가장자리 탭 피드백 위젯
///
/// - 탭 시작 시(onTapDown) 즉각적인 시각적 피드백 제공
/// - 드래그(onPan)로 전환 시 피드백 취소 (onTapCancel)
/// - 테마(Dark/Light)에 따른 적응형 그라데이션
class EdgeTapFeedback extends StatefulWidget {
  const EdgeTapFeedback({
    Key? key,
    required this.onTap,
    required this.isLeftEdge,
    required this.width,
    this.label,
    this.hint,
  }) : super(key: key);

  final VoidCallback onTap;
  final bool isLeftEdge;
  final double width;
  final String? label;
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
        reverseDuration: const Duration(milliseconds: 50));

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

    // 그라데이션: 가장자리(진함) -> 안쪽(투명)
    final gradientColors = [
      baseColor.withValues(alpha: 0.12), // 너무 진하지 않게 12% 불투명도
      baseColor.withValues(alpha: 0.0),
    ];

    final gradient = LinearGradient(
      begin: widget.isLeftEdge ? Alignment.centerLeft : Alignment.centerRight,
      end: widget.isLeftEdge ? Alignment.centerRight : Alignment.centerLeft,
      colors: gradientColors,
    );

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
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Container(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
