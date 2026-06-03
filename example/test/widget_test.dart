import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:real_page_flip_example/main.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book_repository.dart';
import 'package:real_page_flip_example/features/bookshelf/data/book_repository_provider.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';

class MockBookRepository extends Mock implements BookRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bookshelf screen smoke test', (WidgetTester tester) async {
    // Mock SharedPreferences values for testing environment
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockRepository = MockBookRepository();
    when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(mockRepository),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );

    // Pump the initial loading frame (rendering Skeletonizer)
    await tester.pump();

    // Re-pump with a delay to let the mocked future resolve to empty state
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the bookshelf title and empty state text are visible.
    expect(find.text('Realbook 서재'), findsOneWidget);
    expect(find.text('서재가 비어 있습니다'), findsOneWidget);
  });
}
