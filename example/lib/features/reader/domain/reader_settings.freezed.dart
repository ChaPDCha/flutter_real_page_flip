// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReaderSettings _$ReaderSettingsFromJson(Map<String, dynamic> json) {
  return _ReaderSettings.fromJson(json);
}

/// @nodoc
mixin _$ReaderSettings {
  double get fontSize => throw _privateConstructorUsedError;
  double get lineHeight => throw _privateConstructorUsedError;
  bool get enableHaptics => throw _privateConstructorUsedError;
  bool get enableSound => throw _privateConstructorUsedError;
  double get brightness => throw _privateConstructorUsedError;
  String? get fontFamily => throw _privateConstructorUsedError;
  String get hapticTexturePresetName => throw _privateConstructorUsedError;

  /// Serializes this ReaderSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReaderSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReaderSettingsCopyWith<ReaderSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReaderSettingsCopyWith<$Res> {
  factory $ReaderSettingsCopyWith(
    ReaderSettings value,
    $Res Function(ReaderSettings) then,
  ) = _$ReaderSettingsCopyWithImpl<$Res, ReaderSettings>;
  @useResult
  $Res call({
    double fontSize,
    double lineHeight,
    bool enableHaptics,
    bool enableSound,
    double brightness,
    String? fontFamily,
    String hapticTexturePresetName,
  });
}

/// @nodoc
class _$ReaderSettingsCopyWithImpl<$Res, $Val extends ReaderSettings>
    implements $ReaderSettingsCopyWith<$Res> {
  _$ReaderSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReaderSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? enableHaptics = null,
    Object? enableSound = null,
    Object? brightness = null,
    Object? fontFamily = freezed,
    Object? hapticTexturePresetName = null,
  }) {
    return _then(
      _value.copyWith(
            fontSize: null == fontSize
                ? _value.fontSize
                : fontSize // ignore: cast_nullable_to_non_nullable
                      as double,
            lineHeight: null == lineHeight
                ? _value.lineHeight
                : lineHeight // ignore: cast_nullable_to_non_nullable
                      as double,
            enableHaptics: null == enableHaptics
                ? _value.enableHaptics
                : enableHaptics // ignore: cast_nullable_to_non_nullable
                      as bool,
            enableSound: null == enableSound
                ? _value.enableSound
                : enableSound // ignore: cast_nullable_to_non_nullable
                      as bool,
            brightness: null == brightness
                ? _value.brightness
                : brightness // ignore: cast_nullable_to_non_nullable
                      as double,
            fontFamily: freezed == fontFamily
                ? _value.fontFamily
                : fontFamily // ignore: cast_nullable_to_non_nullable
                      as String?,
            hapticTexturePresetName: null == hapticTexturePresetName
                ? _value.hapticTexturePresetName
                : hapticTexturePresetName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReaderSettingsImplCopyWith<$Res>
    implements $ReaderSettingsCopyWith<$Res> {
  factory _$$ReaderSettingsImplCopyWith(
    _$ReaderSettingsImpl value,
    $Res Function(_$ReaderSettingsImpl) then,
  ) = __$$ReaderSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double fontSize,
    double lineHeight,
    bool enableHaptics,
    bool enableSound,
    double brightness,
    String? fontFamily,
    String hapticTexturePresetName,
  });
}

/// @nodoc
class __$$ReaderSettingsImplCopyWithImpl<$Res>
    extends _$ReaderSettingsCopyWithImpl<$Res, _$ReaderSettingsImpl>
    implements _$$ReaderSettingsImplCopyWith<$Res> {
  __$$ReaderSettingsImplCopyWithImpl(
    _$ReaderSettingsImpl _value,
    $Res Function(_$ReaderSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReaderSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fontSize = null,
    Object? lineHeight = null,
    Object? enableHaptics = null,
    Object? enableSound = null,
    Object? brightness = null,
    Object? fontFamily = freezed,
    Object? hapticTexturePresetName = null,
  }) {
    return _then(
      _$ReaderSettingsImpl(
        fontSize: null == fontSize
            ? _value.fontSize
            : fontSize // ignore: cast_nullable_to_non_nullable
                  as double,
        lineHeight: null == lineHeight
            ? _value.lineHeight
            : lineHeight // ignore: cast_nullable_to_non_nullable
                  as double,
        enableHaptics: null == enableHaptics
            ? _value.enableHaptics
            : enableHaptics // ignore: cast_nullable_to_non_nullable
                  as bool,
        enableSound: null == enableSound
            ? _value.enableSound
            : enableSound // ignore: cast_nullable_to_non_nullable
                  as bool,
        brightness: null == brightness
            ? _value.brightness
            : brightness // ignore: cast_nullable_to_non_nullable
                  as double,
        fontFamily: freezed == fontFamily
            ? _value.fontFamily
            : fontFamily // ignore: cast_nullable_to_non_nullable
                  as String?,
        hapticTexturePresetName: null == hapticTexturePresetName
            ? _value.hapticTexturePresetName
            : hapticTexturePresetName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReaderSettingsImpl implements _ReaderSettings {
  const _$ReaderSettingsImpl({
    this.fontSize = 16.0,
    this.lineHeight = 1.6,
    this.enableHaptics = true,
    this.enableSound = true,
    this.brightness = 1.0,
    this.fontFamily,
    this.hapticTexturePresetName = 'standard',
  });

  factory _$ReaderSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReaderSettingsImplFromJson(json);

  @override
  @JsonKey()
  final double fontSize;
  @override
  @JsonKey()
  final double lineHeight;
  @override
  @JsonKey()
  final bool enableHaptics;
  @override
  @JsonKey()
  final bool enableSound;
  @override
  @JsonKey()
  final double brightness;
  @override
  final String? fontFamily;
  @override
  @JsonKey()
  final String hapticTexturePresetName;

  @override
  String toString() {
    return 'ReaderSettings(fontSize: $fontSize, lineHeight: $lineHeight, enableHaptics: $enableHaptics, enableSound: $enableSound, brightness: $brightness, fontFamily: $fontFamily, hapticTexturePresetName: $hapticTexturePresetName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReaderSettingsImpl &&
            (identical(other.fontSize, fontSize) ||
                other.fontSize == fontSize) &&
            (identical(other.lineHeight, lineHeight) ||
                other.lineHeight == lineHeight) &&
            (identical(other.enableHaptics, enableHaptics) ||
                other.enableHaptics == enableHaptics) &&
            (identical(other.enableSound, enableSound) ||
                other.enableSound == enableSound) &&
            (identical(other.brightness, brightness) ||
                other.brightness == brightness) &&
            (identical(other.fontFamily, fontFamily) ||
                other.fontFamily == fontFamily) &&
            (identical(
                  other.hapticTexturePresetName,
                  hapticTexturePresetName,
                ) ||
                other.hapticTexturePresetName == hapticTexturePresetName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    fontSize,
    lineHeight,
    enableHaptics,
    enableSound,
    brightness,
    fontFamily,
    hapticTexturePresetName,
  );

  /// Create a copy of ReaderSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReaderSettingsImplCopyWith<_$ReaderSettingsImpl> get copyWith =>
      __$$ReaderSettingsImplCopyWithImpl<_$ReaderSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ReaderSettingsImplToJson(this);
  }
}

abstract class _ReaderSettings implements ReaderSettings {
  const factory _ReaderSettings({
    final double fontSize,
    final double lineHeight,
    final bool enableHaptics,
    final bool enableSound,
    final double brightness,
    final String? fontFamily,
    final String hapticTexturePresetName,
  }) = _$ReaderSettingsImpl;

  factory _ReaderSettings.fromJson(Map<String, dynamic> json) =
      _$ReaderSettingsImpl.fromJson;

  @override
  double get fontSize;
  @override
  double get lineHeight;
  @override
  bool get enableHaptics;
  @override
  bool get enableSound;
  @override
  double get brightness;
  @override
  String? get fontFamily;
  @override
  String get hapticTexturePresetName;

  /// Create a copy of ReaderSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReaderSettingsImplCopyWith<_$ReaderSettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
