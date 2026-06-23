import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme_controller.dart';
import '../../../shared/theme/reader_theme.dart';
import '../application/sync_provider.dart';
import 'sync_status_badge.dart';

/// Global route observer to monitor screen pops and focus shifts.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class SyncWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const SyncWrapper({super.key, required this.child});

  @override
  ConsumerState<SyncWrapper> createState() => _SyncWrapperState();
}

class _SyncWrapperState extends ConsumerState<SyncWrapper>
    with WidgetsBindingObserver, RouteAware {
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Defer first sync until after the first frame (avoid blocking cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(syncControllerProvider.notifier).sync();
        }
      });
    });

    // 2. 5-Minute background periodic sync timer
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      ref.read(syncControllerProvider.notifier).sync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register this wrapper to listen to push/pop route changes
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 3. Foreground resumption sync hook
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).sync();
    }
  }

  @override
  void didPopNext() {
    // 4. Trigger sync instantly when a pushed screen (e.g. Reader) pops back to this screen
    ref.read(syncControllerProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ReaderThemeData.get(
      ref.watch(appThemeControllerProvider),
    );

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      body: Stack(
        children: [
          widget.child,
          const Align(
            alignment: Alignment.topRight,
            child: SafeArea(child: SyncStatusBadge()),
          ),
        ],
      ),
    );
  }
}
