import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../bookshelf/domain/book.dart';
import '../reader_controller.dart';
import '../../../../l10n/translations.g.dart';

class ReaderSettingsPanel {
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Book book,
    required ReaderController controller,
  }) {
    const theme = ReaderThemeData.charcoal; // Unified to premium dark mode
    final l10n = context.t;

    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: theme.panelColor,
          topBarTitle: Text(
            l10n.readerSettings.title,
            style: ReaderTypography.getUiStyle(
              fontWeight: FontWeight.bold,
              color: theme.textColor,
              fontSize: 16,
            ),
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final currentState = ref.watch(readerControllerProvider(book));

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Font Size
                    _SettingRow(
                      label: l10n.readerSettings.fontSize,
                      theme: theme,
                      child: _SizeControl(
                        value: currentState.settings.fontSize,
                        formatValue: (v) => '${v.toInt()}',
                        onDecrement: () => controller.updateFontSize(-1.0),
                        onIncrement: () => controller.updateFontSize(1.0),
                        theme: theme,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Line Spacing
                    _SettingRow(
                      label: l10n.readerSettings.lineSpacing,
                      theme: theme,
                      child: _SizeControl(
                        value: currentState.settings.lineHeight,
                        formatValue: (v) => v.toStringAsFixed(1),
                        onDecrement: () => controller.updateLineHeight(-0.1),
                        onIncrement: () => controller.updateLineHeight(0.1),
                        theme: theme,
                        step: 0.1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Brightness
                    _SettingRow(
                      label: l10n.readerSettings.brightness,
                      theme: theme,
                      child: SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            Icon(
                              Icons.brightness_low,
                              color: theme.secondaryTextColor,
                              size: 15,
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 12,
                                  ),
                                  activeTrackColor: theme.accentColor,
                                  inactiveTrackColor: theme.dividerColor,
                                  thumbColor: theme.accentColor,
                                  overlayColor: theme.accentColor.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                                child: Slider(
                                  value: currentState.settings.brightness,
                                  min: 0.3,
                                  max: 1.0,
                                  divisions: 14,
                                  onChanged: (val) =>
                                      controller.updateBrightness(val),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.brightness_high,
                              color: theme.secondaryTextColor,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Font Family
                    _SettingRow(
                      label: l10n.readerSettings.font,
                      theme: theme,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FontOption(
                            label: l10n.readerSettings.fontOptions.gothic,
                            isSelected:
                                currentState.settings.fontFamily == null,
                            onTap: () => controller.updateFontFamily(null),
                            theme: theme,
                          ),
                          const SizedBox(width: 8),
                          _FontOption(
                            label: l10n.readerSettings.fontOptions.myungjo,
                            isSelected:
                                currentState.settings.fontFamily == 'serif',
                            onTap: () => controller.updateFontFamily(
                              currentState.settings.fontFamily == 'serif'
                                  ? null
                                  : 'serif',
                            ),
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Haptics
                    _SettingRow(
                      label: l10n.readerSettings.haptics,
                      theme: theme,
                      child: ShadSwitch(
                        value: currentState.settings.enableHaptics,
                        onChanged: (val) async {
                          await controller.toggleHaptics(val);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Paper Texture Preset
                    _SettingRow(
                      label: l10n.readerSettings.texture,
                      theme: theme,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TextureChip(
                            label: l10n.readerSettings.textureOptions.smooth,
                            isSelected: currentState
                                    .settings.hapticTexturePresetName ==
                                'smooth',
                            onTap: () =>
                                controller.updateHapticTexturePreset('smooth'),
                            theme: theme,
                          ),
                          const SizedBox(width: 6),
                          _TextureChip(
                            label: l10n.readerSettings.textureOptions.standard,
                            isSelected: currentState
                                    .settings.hapticTexturePresetName ==
                                'standard',
                            onTap: () => controller
                                .updateHapticTexturePreset('standard'),
                            theme: theme,
                          ),
                          const SizedBox(width: 6),
                          _TextureChip(
                            label: l10n.readerSettings.textureOptions.textured,
                            isSelected: currentState
                                    .settings.hapticTexturePresetName ==
                                'textured',
                            onTap: () => controller
                                .updateHapticTexturePreset('textured'),
                            theme: theme,
                          ),
                          const SizedBox(width: 6),
                          _TextureChip(
                            label: l10n.readerSettings.textureOptions.kraft,
                            isSelected: currentState
                                    .settings.hapticTexturePresetName ==
                                'kraft',
                            onTap: () => controller
                                .updateHapticTexturePreset('kraft'),
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sound
                    _SettingRow(
                      label: l10n.readerSettings.sound,
                      theme: theme,
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
                l10n.readerSettings.done,
                style: ReaderTypography.getUiStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
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
            style: ReaderTypography.getUiStyle(
              color: theme.textColor,
              fontSize: 14,
            ),
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
          icon: Icon(Icons.remove, color: theme.textColor, size: 15),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        SizedBox(
          width: 32,
          child: Text(
            formatValue(value),
            textAlign: TextAlign.center,
            style: ReaderTypography.getGeometricStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: Icon(Icons.add, color: theme.textColor, size: 15),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

/// A small selectable chip for paper texture preset.
class _TextureChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ReaderThemeData theme;

  const _TextureChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.dividerColor,
            width: isSelected ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: ReaderTypography.getUiStyle(
            color: isSelected ? theme.accentColor : theme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.dividerColor,
            width: isSelected ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: ReaderTypography.getUiStyle(
            color: isSelected ? theme.accentColor : theme.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
