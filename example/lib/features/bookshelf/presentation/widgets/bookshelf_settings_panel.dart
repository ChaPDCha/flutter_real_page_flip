import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../../l10n/translations.g.dart';
import '../../../sync/application/sync_provider.dart';
import '../../../sync/domain/sync_state.dart';

class BookshelfSettingsPanel {
  static void show({required BuildContext context, required WidgetRef ref}) {
    const theme = ReaderThemeData.charcoal; // Unified to dark mode
    final l10n = context.t;

    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: theme.panelColor,
          topBarTitle: Text(
            l10n.settingsPanel.title,
            style: ReaderTypography.getUiStyle(
              fontWeight: FontWeight.bold,
              color: theme.textColor,
              fontSize: 16,
            ),
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final syncState = ref.watch(syncControllerProvider);
              final syncNotifier = ref.read(syncControllerProvider.notifier);

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Cloud Sync
                    _buildSectionHeader(l10n.settingsPanel.cloudSync, theme),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.settingsPanel.syncStatus,
                                  style: ReaderTypography.getUiStyle(
                                    color: theme.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildStatusIndicator(
                                      syncState.status,
                                      theme,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getSyncStatusText(syncState.status, l10n),
                                      style: ReaderTypography.getUiStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ShadButton(
                            onPressed:
                                syncState.status == SyncStatus.pulling ||
                                    syncState.status == SyncStatus.pushing ||
                                    syncState.status ==
                                        SyncStatus.authenticating
                                ? null
                                : () => syncNotifier.sync(),
                            backgroundColor: theme.accentColor,
                            foregroundColor: theme.buttonForegroundColor,
                            size: ShadButtonSize.sm,
                            child: Text(
                              l10n.settingsPanel.syncNow,
                              style: ReaderTypography.getUiStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section 2: App Info
                    _buildSectionHeader(l10n.settingsPanel.appInfo, theme),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(l10n.settingsPanel.version, 'v1.7.2', theme),
                          Divider(color: theme.dividerColor, height: 24),
                          _buildInfoRow(l10n.settingsPanel.engine, '3D PageFlip Core v2.5.0', theme),
                          Divider(color: theme.dividerColor, height: 24),
                          _buildInfoRow(l10n.settingsPanel.status, l10n.settingsPanel.darkMode, theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
          stickyActionBar: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ShadButton(
              onPressed: () => Navigator.of(modalContext).pop(),
              backgroundColor: theme.accentColor,
              foregroundColor: theme.buttonForegroundColor,
              width: double.infinity,
              child: Text(
                l10n.settingsPanel.done,
                style: ReaderTypography.getUiStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildSectionHeader(String title, ReaderThemeData theme) {
    return Text(
      title,
      style: ReaderTypography.getUiStyle(
        color: theme.secondaryTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    );
  }

  static Widget _buildInfoRow(
    String label,
    String value,
    ReaderThemeData theme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: ReaderTypography.getUiStyle(
            color: theme.secondaryTextColor,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: ReaderTypography.getGeometricStyle(
            color: theme.textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  static Widget _buildStatusIndicator(
    SyncStatus status,
    ReaderThemeData theme,
  ) {
    Color color = theme.secondaryTextColor;
    switch (status) {
      case SyncStatus.authenticating:
      case SyncStatus.pulling:
      case SyncStatus.pushing:
        color = theme.accentColor;
        break;
      case SyncStatus.success:
        color = ReaderThemeData.successColor;
        break;
      case SyncStatus.error:
        color = ReaderThemeData.errorColor;
        break;
      case SyncStatus.idle:
        color = theme.secondaryTextColor.withValues(alpha: 0.4);
        break;
    }

    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static String _getSyncStatusText(SyncStatus status, Translations l10n) {
    switch (status) {
      case SyncStatus.idle:
        return l10n.settingsPanel.syncWaiting;
      case SyncStatus.authenticating:
        return l10n.settingsPanel.syncVerifying;
      case SyncStatus.pulling:
      case SyncStatus.pushing:
        return l10n.settingsPanel.syncing;
      case SyncStatus.success:
        return l10n.settingsPanel.syncCompleted;
      case SyncStatus.error:
        return l10n.settingsPanel.syncError;
    }
  }
}
