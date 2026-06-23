import 'package:freezed_annotation/freezed_annotation.dart';

part 'reader_settings.freezed.dart';
part 'reader_settings.g.dart';

@freezed
class ReaderSettings with _$ReaderSettings {
  const factory ReaderSettings({
    @Default(16.0) double fontSize,
    @Default(1.6) double lineHeight,
    @Default(true) bool enableHaptics,
    @Default(true) bool enableSound,
    @Default(1.0) double brightness,
    String? fontFamily,
  }) = _ReaderSettings;

  factory ReaderSettings.fromJson(Map<String, dynamic> json) =>
      _$ReaderSettingsFromJson(json);
}
