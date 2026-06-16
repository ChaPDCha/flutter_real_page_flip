import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/book.dart';
import '../data/book_repository_provider.dart';
import '../../reader/application/search_service_provider.dart';

part 'bookshelf_controller.g.dart';

const String _demoBookId = 'book_demo';
const String _kDemoCreatedPref = 'demo_book_created';

@riverpod
class BookshelfController extends _$BookshelfController {
  @override
  FutureOr<List<Book>> build() async {
    final books = await _loadBooks();
    if (books.isEmpty) {
      await _ensureDemoBook();
      return _loadBooks();
    }
    return books;
  }

  Future<List<Book>> _loadBooks() {
    return ref.read(bookRepositoryProvider).getBooks();
  }

  Future<void> _ensureDemoBook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kDemoCreatedPref) == true) return;

      final docDir = await getApplicationDocumentsDirectory();

      // Create demo book directory
      final targetDir = Directory(p.join(docDir.path, 'books'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Generate demo TXT content
      final demoContent = _generateDemoContent();
      final targetPath = p.join(targetDir.path, '$_demoBookId.txt');
      await File(targetPath).writeAsString(demoContent);

      final book = Book(
        id: _demoBookId,
        title: 'Realbook 데모',
        author: 'Realbook Team',
        filePath: targetPath,
        addedAt: DateTime.now(),
      );

      await ref.read(bookRepositoryProvider).addBook(book);
      await ref.read(searchServiceProvider).indexBook(book);
      await prefs.setBool(_kDemoCreatedPref, true);
    } catch (_) {
      // Gracefully handle demo book creation failure
    }
  }

  String _generateDemoContent() {
    final buf = StringBuffer();
    final chs = ['봄날의 산책', '여름의 기억', '가을 편지', '겨울 이야기', '비 오는 날',
      '별이 빛나는 밤에', '바람이 부는 언덕', '강가에서', '숲 속으로', '일상의 발견'];
    final ss = ['오늘은 유난히 날씨가 좋았다. 하늘은 맑고 공기는 상쾌했다.',
      '아침 일찍 일어나 창문을 열었다. 신선한 공기가 방 안으로 가득 들어왔다.',
      '길을 걷다 보니 생각보다 많은 것들이 눈에 들어왔다.',
      '조용히 앉아 주변을 관찰하기로 했다. 사람들은 각자의 길을 가고 있었다.',
      '커피 한 잔을 들고 창가에 앉았다. 밖에서는 사람들이 분주히 오가고 있었다.'];
    final ms = ['햇살이 따사롭게 내리쬐고 있었다. 가벼운 바람이 뺨을 스치며 지나갔다.',
      '햇빛이 부드럽게 쏟아지고 있었다. 나뭇잎이 바람에 살랑살랑 흔들렸다.',
      '산에는 아침 안개가 자욱하게 끼어 있었다. 하늘과 땅을 구분 짓는 장막 같았다.',
      '시간이 흐르면서 생각이 정리되기 시작했다. 복잡했던 마음이 차분해졌다.',
      '발걸음을 옮길 때마다 새로운 풍경이 펼쳐졌다. 골목길을 돌아서자 작은 꽃집이 나타났다.',
      '햇살이 눈부시게 내리쬐던 날, 나는 오랜만에 집을 나섰다. 발길이 닿는 곳마다 새로운 발견이 있었다.',
      '책 한 권을 펼쳐 들고 읽기 시작했다. 이야기에 빠져들면서 시간 가는 줄 몰랐다.',
      '저녁 식사를 준비하면서 오늘 하루를 되돌아보았다. 간단한 요리지만 뿌듯함이 있었다.',
      '주말에는 가까운 공원에 가기로 했다. 많은 사람들이 나와 있었다. 돗자리를 펴고 여유를 즐겼다.',
      '벤치에 앉아 명상을 했다. 눈을 감고 깊게 숨을 쉬었다. 마음이 평온해졌다.'];
    final ds = ['아이들은 신나게 뛰어놀고 있었고, 연인들은 손을 잡고 산책을 즐기고 있었다.',
      '꽃잎마다 맺힌 이슬방울이 보석처럼 반짝이고 있었다. 카페에 들러 따뜻한 차를 주문했다.',
      '좋은 책은 언제나 삶의 동기가 되어준다. 친구에게 짧은 메시지를 보냈다.',
      '평범한 하루의 소중함을 기록하고 싶었다. 음악을 들으며 집으로 돌아가는 길이었다.',
      '비가 내리기 시작했다. 처음에는 보슬비였지만 점점 굵어졌다. 빗방울이 상쾌했다.',
      '사진을 찍으며 산책을 즐겼다. 작은 풍경들이 카메라 렌즈로는 특별하게 보였다.',
      '도서관에 들러 새로운 책을 빌렸다. 책장 사이를 거닐며 다양한 책들을 구경했다.',
      '비 온 뒤의 세상은 항상 새롭게 보인다. 공기가 맑아지고 모든 것이 생생해졌다.',
      '오래 연락하지 못했지만 마음은 항상 가까이 있다. 진정한 우정은 변하지 않는다.',
      '눈을 감고 깊게 숨을 쉬었다. 모든 걱정이 사라지는 느낌이었다.'];
    final es = ['작은 행복들이 생각보다 많이 있었다. 충분히 가치 있는 하루였다.',
      '발걸음이 가볍다. 내일을 위한 에너지를 충전한 기분이다.',
      '별들이 하나둘씩 모습을 드러냈다. 내일은 더 나은 하루가 되기를 바란다.',
      '하늘이 붉게 물들었다. 석양을 바라보며 하루를 마무리했다.',
      '어둠이 내리기 시작했다. 잘 쉬고 내일 다시 힘내자.'];
    for (int c = 0; c < chs.length; c++) {
      buf.writeln('제${c+1}장: ${chs[c]}'); buf.writeln();
      for (int p = 0; p < 30; p++) {
        buf.writeln('${ss[(c+p)%ss.length]} ${ms[(c+p)%ms.length]} ${ds[(p*2+c)%ds.length]} ${es[(c+p)%es.length]}');
        buf.writeln();
      }
      buf.writeln();
    }
    return buf.toString();
  }

  Future<void> importBook(File file) async {
    state = const AsyncValue.loading();
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path).toLowerCase();
      final bookId = 'book_$timestamp';

      String title = originalName;
      String author = 'Unknown Author';
      String? coverImagePath;

      if (ext == '.epub') {
        // Read EPUB metadata
        final bytes = await file.readAsBytes();
        final epubBook = await compute(EpubReader.readBook, bytes);
        
        title = epubBook.Title?.trim().isNotEmpty == true 
            ? epubBook.Title! 
            : originalName;
        author = epubBook.Author?.trim().isNotEmpty == true 
            ? epubBook.Author! 
            : 'Unknown Author';

        // Save cover image if exists
        if (epubBook.CoverImage != null) {
          final coverDir = Directory(p.join(docDir.path, 'covers'));
          if (!await coverDir.exists()) {
            await coverDir.create(recursive: true);
          }
          final coverFile = File(p.join(coverDir.path, '$bookId.png'));
          final pngBytes = await compute(img.encodePng, epubBook.CoverImage!);
          await coverFile.writeAsBytes(pngBytes);
          coverImagePath = coverFile.path;
        }
      } else {
        // TXT or PDF defaults
        title = originalName;
        author = 'Unknown Author';
      }

      // Copy book file to documents directory
      final targetDir = Directory(p.join(docDir.path, 'books'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final targetPath = p.join(targetDir.path, '$bookId$ext');
      await file.copy(targetPath);

      final book = Book(
        id: bookId,
        title: title,
        author: author,
        filePath: targetPath,
        coverImagePath: coverImagePath,
        addedAt: DateTime.now(),
      );

      await ref.read(bookRepositoryProvider).addBook(book);
      ref.read(searchServiceProvider).indexBook(book);
      state = AsyncValue.data(await _loadBooks());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Alias for backward compatibility
  Future<void> importEpub(File file) => importBook(file);

  Future<void> removeBook(String id) async {
    state = const AsyncValue.loading();
    try {
      final books = await _loadBooks();
      final targetBook = books.firstWhere((b) => b.id == id);

      // Delete EPUB file
      final file = File(targetBook.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Delete cover image if exists
      if (targetBook.coverImagePath != null) {
        final coverFile = File(targetBook.coverImagePath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }

      await ref.read(bookRepositoryProvider).removeBook(id);
      state = AsyncValue.data(await _loadBooks());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
