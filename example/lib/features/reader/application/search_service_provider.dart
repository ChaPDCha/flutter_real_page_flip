import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../bookshelf/data/book_repository_provider.dart';
import 'search_service.dart';

part 'search_service_provider.g.dart';

@riverpod
SearchService searchService(SearchServiceRef ref) {
  final db = ref.watch(appDatabaseProvider);
  return SearchService(db);
}
