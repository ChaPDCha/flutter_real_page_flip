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

                    // Font Size
                    _SettingRow(
                      label: '글자 크기',
                      theme: currentTheme,
                      child: _SizeControl(
                        value: currentState.settings.fontSize,
                        formatValue: (v) => '${v.toInt()}',
                        onDecrement: () => controller.updateFontSize(-1.0),
                        onIncrement: () => controller.updateFontSize(1.0),
                        theme: currentTheme,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Line Spacing
                    _SettingRow(
                      label: '줄 간격',
                      theme: currentTheme,
                      child: _SizeControl(
                        value: currentState.settings.lineHeight,
                        formatValue: (v) => v.toStringAsFixed(1),
                        onDecrement: () => controller.updateLineHeight(-0.1),
                        onIncrement: () => controller.updateLineHeight(0.1),
                        theme: currentTheme,
                        step: 0.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Brightness
                    _SettingRow(
                      label: '화면 밝기',
                      theme: currentTheme,
                      child: SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            Icon(Icons.brightness_low, color: currentTheme.secondaryTextColor, size: 16),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                                  activeTrackColor: currentTheme.accentColor,
                                  inactiveTrackColor: currentTheme.dividerColor,
                                  thumbColor: currentTheme.accentColor,
                                  overlayColor: currentTheme.accentColor.withValues(alpha: 0.12),
                                ),
                                child: Slider(
                                  value: currentState.settings.brightness,
                                  min: 0.3,
                                  max: 1.0,
                                  divisions: 14,
                                  onChanged: (val) => controller.updateBrightness(val),
                                ),
                              ),
                            ),
                            Icon(Icons.brightness_high, color: currentTheme.secondaryTextColor, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Font Family
                    _SettingRow(
                      label: '글꼴',
                      theme: currentTheme,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FontOption(
                            label: '기본',
                            isSelected: currentState.settings.fontFamily == null,
                            onTap: () => controller.updateFontFamily(null),
                            theme: currentTheme,
                          ),
                          const SizedBox(width: 8),
                          _FontOption(
                            label: 'Serif',
                            isSelected: currentState.settings.fontFamily == 'serif',
                            onTap: () => controller.updateFontFamily(
                              currentState.settings.fontFamily == 'serif' ? null : 'serif',
                            ),
                            theme: currentTheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Haptics
                    _SettingRow(
                      label: '햅틱 피드백',
                      theme: currentTheme,
                      child: ShadSwitch(
                        value: currentState.settings.enableHaptics,
                        onChanged: (val) async {
                          await controller.toggleHaptics(val);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sound
                    _SettingRow(
                      label: '소리 효과',
                      theme: currentTheme,
                      child: ShadSwitch(
                        value: currentState.settings.enableSound,
                        onChanged: (val) async {
                          await controller.toggleSound(val);
                        },
                      ),
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

/// A labeled row for a single setting.
class _SettingRow extends StatelessWidget {
  final String label;
  final ReaderThemeData theme;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.textColor, fontSize: 14),
          ),
        ),
        child,
      ],
    );
  }
}

/// Plus/minus controls for numeric settings (font size, line spacing).
class _SizeControl extends StatelessWidget {
  final double value;
  final String Function(double) formatValue;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ReaderThemeData theme;
  final double step;

  const _SizeControl({
    required this.value,
    required this.formatValue,
    required this.onDecrement,
    required this.onIncrement,
    required this.theme,
    this.step = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onDecrement,
          icon: Icon(Icons.remove, color: theme.textColor, size: 16),
        ),
        SizedBox(
          width: 36,
          child: Text(
            formatValue(value),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: Icon(Icons.add, color: theme.textColor, size: 16),
        ),
      ],
    );
  }
}

/// A small selectable chip for font family options.
class _FontOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ReaderThemeData theme;

  const _FontOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.accentColor : theme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            fontFamily: label == 'Serif' ? 'serif' : null,
          ),
        ),
      ),
    );
  }
}
