import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../shared/theme/app_theme_controller.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../bookshelf/domain/book.dart';
import '../reader_controller.dart';
import '../reader_state.dart';

class ReaderSettingsPanel {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Book book,
    required ReaderState state,
    required ReaderController controller,
  }) {
    final theme = ReaderThemeData.get(ref.read(appThemeControllerProvider));

    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: theme.panelColor,
          topBarTitle: Text(
            '독서 설정',
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor, fontSize: 16),
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final currentState = ref.watch(readerControllerProvider(book));
              final themeType = ref.watch(appThemeControllerProvider);
              final currentTheme = ReaderThemeData.get(themeType);

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('테마 설정', style: TextStyle(color: currentTheme.textColor, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildThemeOption(
                            ref,
                            ReaderThemeType.cream,
                            '크림',
                            currentTheme,
                            themeType,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildThemeOption(
                            ref,
                            ReaderThemeType.charcoal,
                            '차콜',
                            currentTheme,
                            themeType,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '글자 크기',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: currentTheme.textColor, fontSize: 14),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await controller.updateFontSize(-1.0);
                              },
                              icon: Icon(Icons.remove, color: currentTheme.textColor, size: 16),
                            ),
                            Text(
                              '${currentState.settings.fontSize.toInt()}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: currentTheme.textColor),
                            ),
                            IconButton(
                              onPressed: () async {
                                await controller.updateFontSize(1.0);
                              },
                              icon: Icon(Icons.add, color: currentTheme.textColor, size: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '햅틱 피드백',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: currentTheme.textColor, fontSize: 14),
                          ),
                        ),
                        ShadSwitch(
                          value: currentState.settings.enableHaptics,
                          onChanged: (val) async {
                            await controller.toggleHaptics(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '소리 효과',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: currentTheme.textColor, fontSize: 14),
                          ),
                        ),
                        ShadSwitch(
                          value: currentState.settings.enableSound,
                          onChanged: (val) async {
                            await controller.toggleSound(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            }
          ),
          stickyActionBar: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer(
              builder: (context, ref, child) {
                final currentTheme = ReaderThemeData.get(ref.watch(appThemeControllerProvider));
                return ShadButton(
                  onPressed: () => Navigator.of(modalContext).pop(),
                  backgroundColor: currentTheme.accentColor,
                  foregroundColor: currentTheme.buttonForegroundColor,
                  width: double.infinity,
                  child: const Text('설정 완료'),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildThemeOption(
    WidgetRef ref,
    ReaderThemeType type,
    String name,
    ReaderThemeData panelTheme,
    ReaderThemeType currentType,
  ) {
    final optionTheme = ReaderThemeData.get(type);
    final isSelected = type == currentType;
    return GestureDetector(
      onTap: () {
        ref.read(appThemeControllerProvider.notifier).setTheme(type);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: optionTheme.backgroundColor,
          border: Border.all(
            color: isSelected ? panelTheme.accentColor : optionTheme.dividerColor,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: optionTheme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
