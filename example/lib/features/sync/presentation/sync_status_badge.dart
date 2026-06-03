import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/sync_provider.dart';
import '../domain/sync_state.dart';

class SyncStatusBadge extends ConsumerStatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  ConsumerState<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends ConsumerState<SyncStatusBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isVisible = false;
  Color _dotColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.2,
      upperBound: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateBadge(ref.read(syncControllerProvider));
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateBadge(SyncState syncState) {
    final status = syncState.status;

    if (status == SyncStatus.idle) {
      _isVisible = false;
      _pulseController.stop();
      return;
    }

    _isVisible = true;
    switch (status) {
      case SyncStatus.authenticating:
      case SyncStatus.pulling:
      case SyncStatus.pushing:
        _dotColor = const Color(0xFFD4AF37); // Soft elegant gold
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        break;
      case SyncStatus.success:
        _dotColor = const Color(0xFF4CAF50); // Soft green
        _pulseController.stop();
        _pulseController.value = 1.0;
        // Automatically fade out after 2 seconds of success state
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && ref.read(syncControllerProvider).status == SyncStatus.success) {
            setState(() => _isVisible = false);
          }
        });
        break;
      case SyncStatus.error:
        _dotColor = const Color(0xFFE53935); // Soft red
        _pulseController.stop();
        _pulseController.value = 1.0;
        // Auto fade out error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && ref.read(syncControllerProvider).status == SyncStatus.error) {
            setState(() => _isVisible = false);
          }
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider, (_, next) {
      _updateBadge(next);
    });

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      child: _isVisible
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseController.value,
                    child: child,
                  );
                },
                child: Container(
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _dotColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
