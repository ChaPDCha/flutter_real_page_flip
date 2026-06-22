import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../sync/application/sync_provider.dart';
import '../../../sync/domain/sync_state.dart';

class BookshelfSettingsPanel {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    const theme = ReaderThemeData.charcoal; // Unified to dark mode

    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: theme.panelColor,
          topBarTitle: Text(
            '서재 설정',
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
                    _buildSectionHeader('클라우드 동기화', theme),
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
                                  '서재 동기화 상태',
                                  style: ReaderTypography.getUiStyle(
                                    color: theme.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildStatusIndicator(syncState.status, theme),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getSyncStatusText(syncState.status),
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
                            onPressed: syncState.status == SyncStatus.pulling ||
                                    syncState.status == SyncStatus.pushing ||
                                    syncState.status == SyncStatus.authenticating
                                ? null
                                : () => syncNotifier.sync(),
                            backgroundColor: theme.accentColor,
                            foregroundColor: theme.buttonForegroundColor,
                            size: ShadButtonSize.sm,
                            child: Text(
                              '지금 동기화',
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
                    _buildSectionHeader('애플리케이션 정보', theme),
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
                          _buildInfoRow('버전', 'v1.5.2', theme),
                          Divider(color: theme.dividerColor, height: 24),
                          _buildInfoRow('엔진', '3D PageFlip Core v2.5.0', theme),
                          Divider(color: theme.dividerColor, height: 24),
                          _buildInfoRow('상태', '다크 모드 활성화됨', theme),
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
                '설정 완료',
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

  static Widget _buildInfoRow(String label, String value, ReaderThemeData theme) {
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

  static Widget _buildStatusIndicator(SyncStatus status, ReaderThemeData theme) {
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  static String _getSyncStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return '대기 중';
      case SyncStatus.authenticating:
        return '인증 확인 중...';
      case SyncStatus.pulling:
        return '서재 동기화 가져오는 중...';
      case SyncStatus.pushing:
        return '서재 상태 저장 중...';
      case SyncStatus.success:
        return '동기화 완료';
      case SyncStatus.error:
        return '동기화 중 오류 발생';
    }
  }
}
