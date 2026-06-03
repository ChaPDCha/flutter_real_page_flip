import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'supertonic_tts_service.dart';

part 'supertonic_tts_provider.g.dart';

@riverpod
SupertonicTtsService supertonicTts(SupertonicTtsRef ref) {
  final service = SupertonicTtsService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}

@riverpod
class ActiveTtsPageIndex extends _$ActiveTtsPageIndex {
  @override
  int? build() => null;

  void set(int? index) {
    state = index;
  }
}

@riverpod
class ActiveTtsStartOffset extends _$ActiveTtsStartOffset {
  @override
  int build() => 0;

  void set(int offset) {
    state = offset;
  }
}

