// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReaderSettingsImpl _$$ReaderSettingsImplFromJson(Map<String, dynamic> json) =>
    _$ReaderSettingsImpl(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.6,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      enableSound: json['enableSound'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
      fontFamily: json['fontFamily'] as String?,
      hapticTexturePresetName:
          json['hapticTexturePresetName'] as String? ?? 'standard',
      enableDoublePage: json['enableDoublePage'] as bool? ?? false,
    );

Map<String, dynamic> _$$ReaderSettingsImplToJson(
  _$ReaderSettingsImpl instance,
) => <String, dynamic>{
  'fontSize': instance.fontSize,
  'lineHeight': instance.lineHeight,
  'enableHaptics': instance.enableHaptics,
  'enableSound': instance.enableSound,
  'brightness': instance.brightness,
  'fontFamily': instance.fontFamily,
  'hapticTexturePresetName': instance.hapticTexturePresetName,
  'enableDoublePage': instance.enableDoublePage,
};
