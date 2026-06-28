// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$readerControllerHash() => r'2aeff7a802f74b40f77ea8d4cc1183ae266b5523';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ReaderController
    extends BuildlessAutoDisposeNotifier<ReaderState> {
  late final Book book;

  ReaderState build(Book book);
}

/// See also [ReaderController].
@ProviderFor(ReaderController)
const readerControllerProvider = ReaderControllerFamily();

/// See also [ReaderController].
class ReaderControllerFamily extends Family<ReaderState> {
  /// See also [ReaderController].
  const ReaderControllerFamily();

  /// See also [ReaderController].
  ReaderControllerProvider call(Book book) {
    return ReaderControllerProvider(book);
  }

  @override
  ReaderControllerProvider getProviderOverride(
    covariant ReaderControllerProvider provider,
  ) {
    return call(provider.book);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'readerControllerProvider';
}

/// See also [ReaderController].
class ReaderControllerProvider
    extends AutoDisposeNotifierProviderImpl<ReaderController, ReaderState> {
  /// See also [ReaderController].
  ReaderControllerProvider(Book book)
    : this._internal(
        () => ReaderController()..book = book,
        from: readerControllerProvider,
        name: r'readerControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$readerControllerHash,
        dependencies: ReaderControllerFamily._dependencies,
        allTransitiveDependencies:
            ReaderControllerFamily._allTransitiveDependencies,
        book: book,
      );

  ReaderControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.book,
  }) : super.internal();

  final Book book;

  @override
  ReaderState runNotifierBuild(covariant ReaderController notifier) {
    return notifier.build(book);
  }

  @override
  Override overrideWith(ReaderController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ReaderControllerProvider._internal(
        () => create()..book = book,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        book: book,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<ReaderController, ReaderState>
  createElement() {
    return _ReaderControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderControllerProvider && other.book == book;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, book.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ReaderControllerRef on AutoDisposeNotifierProviderRef<ReaderState> {
  /// The parameter `book` of this provider.
  Book get book;
}

class _ReaderControllerProviderElement
    extends AutoDisposeNotifierProviderElement<ReaderController, ReaderState>
    with ReaderControllerRef {
  _ReaderControllerProviderElement(super.provider);

  @override
  Book get book => (origin as ReaderControllerProvider).book;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
