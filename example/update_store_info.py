import os
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Ensure stdout supports UTF-8 on Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE_NAME = "app.realbook.reader"
SERVICE_ACCOUNT_FILE = r"h:\Automation\Realbook\example\realbook-499611-8d1668252760.json"

# Local asset paths
ICON_PATH = r"h:\Automation\Realbook\example\assets\branding\play_store_icon.png"
FEATURE_GRAPHIC_PATH = r"h:\Automation\Realbook\example\screenshots\feature_graphic.png"
SCREENSHOTS = [
    r"h:\Automation\Realbook\example\screenshots\ss_bookshelf.png",
    r"h:\Automation\Realbook\example\screenshots\ss_reader_light.png",
    r"h:\Automation\Realbook\example\screenshots\ss_reader_dark.png",
    r"h:\Automation\Realbook\example\screenshots\ss_double_page.png",
    r"h:\Automation\Realbook\example\screenshots\ss_features.png",
]

# Listing texts
LISTINGS = {
    "en-US": {
        "title": "Realbook: 3D Page Flip Reader",
        "shortDescription": "3D page flip reader. EPUB, PDF, TXT, TTS, dark mode & cloud sync.",
        "fullDescription": (
            "Experience the joy of reading with Realbook — the only e-book reader that brings the feel of "
            "a real paper book to your screen.\n\n"
            "WHY REALBOOK?\n\n"
            "• REALISTIC 3D PAGE FLIP\n"
            "Turn pages just like a real book. Our physics-based engine simulates paper texture, corner "
            "folding, and natural page movement. It is not an animation — it is a simulation.\n\n"
            "• ALL YOUR FORMATS IN ONE PLACE\n"
            "Read EPUB, PDF, and TXT files without conversion. Import from your device or cloud storage "
            "and start reading instantly.\n\n"
            "• LISTEN WITH TTS\n"
            "Built-in Text-to-Speech reads any book aloud. Perfect for commuting, workouts, or winding down "
            "before bed.\n\n"
            "• DAY & NIGHT MODES\n"
            "Switch between warm paper-like light mode and eye-friendly dark mode. Reading comfort at any hour.\n\n"
            "• TWO-PAGE SPREAD\n"
            "Turn your phone sideways for a two-page view that mirrors a real open book — complete with a "
            "center spine line.\n\n"
            "• FULL-TEXT SEARCH\n"
            "Find every word, every passage instantly. No more flipping back and forth.\n\n"
            "• CLOUD SYNC\n"
            "Your library, bookmarks, and reading progress sync seamlessly across devices.\n\n"
            "• CLEAN, DISTRACTION-FREE\n"
            "No clutter, no ads interrupting your flow. Just you and your book.\n\n"
            "Download Realbook today and fall in love with reading all over again."
        )
    },
    "ko-KR": {
        "title": "Realbook: 3D 페이지 플립 전자책 리더",
        "shortDescription": "3D 페이지 플립 eBook 리더. EPUB, PDF, TXT, TTS, 다크모드, 클라우드 동기화.",
        "fullDescription": (
            "Realbook은 실제 종이책의 감각을 그대로 스크린에 옮겨놓은 전자책 리더입니다.\n\n"
            "왜 REALBOOK인가요?\n\n"
            "• 실제 같은 3D 페이지 플립\n"
            "물리 엔진 기반의 페이지 넘김은 종이 질감, 모서리 접힘, 자연스러운 움직임을 시뮬레이션합니다. "
            "단순한 애니메이션이 아닌, 진짜 책을 읽는 경험 그 자체입니다.\n\n"
            "• 모든 포맷 지원\n"
            "EPUB, PDF, TXT 파일을 변환 없이 바로 읽으세요. 기기나 클라우드에서 불러와 즉시 독서를 시작할 수 있습니다.\n\n"
            "• TTS 읽어주기 기능\n"
            "내장 Text-to-Speech가 모든 책을 소리내어 읽어줍니다. 출퇴근 길, 운동 중, 잠들기 전까지 언제 어디서나 책을 들어보세요.\n\n"
            "• 낮과 밤 모드\n"
            "따뜻한 종이 질감의 라이트 모드와 눈에 부담 없는 다크 모드를 자유롭게 전환하세요.\n\n"
            "• 두 페이지 보기\n"
            "가로로 돌리면 실제 책처럼 두 페이지가 나란히 펼쳐집니다. 중앙의 책등 라인이 현실감을 더해줍니다.\n\n"
            "• 전체 검색\n"
            "모든 단어, 모든 구절을 즉시 찾아보세요. 더 이상 페이지를 뒤적일 필요가 없습니다.\n\n"
            "• 클라우드 동기화\n"
            "서재, 북마크, 읽기 진행 상황이 모든 기기에서 자동으로 동기화됩니다.\n\n"
            "• 깔끔한 집중 환경\n"
            "광고 없이, 방해 요소 없이. 오직 책과 나만의 시간.\n\n"
            "지금 Realbook을 다운로드하고 책 읽는 즐거움을 다시 발견하세요."
        )
    }
}

def main():
    # 1. Validate local files
    files_to_check = [ICON_PATH, FEATURE_GRAPHIC_PATH] + SCREENSHOTS
    for file_path in files_to_check:
        if not os.path.exists(file_path):
            sys.exit(f"Required local file not found: {file_path}")
    print("All local assets validated successfully.")

    # 2. Build publisher service
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    # 3. Create edit transaction
    edit_request = service.edits().insert(body={}, packageName=PACKAGE_NAME)
    edit_response = edit_request.execute()
    edit_id = edit_response["id"]
    print(f"Created Play Store edit transaction: {edit_id}")

    try:
        # 4. Update listings and graphic assets for each language
        for lang, content in LISTINGS.items():
            print(f"\n--- Processing locale: {lang} ---")
            
            # A. Update Text Listing
            print(f"Updating store text listing (Title, Descriptions)...")
            service.edits().listings().update(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                body={
                    "title": content["title"],
                    "shortDescription": content["shortDescription"],
                    "fullDescription": content["fullDescription"]
                }
            ).execute()
            print("Store text listing updated.")

            # B. Update Icon
            print("Updating store icon (logo)...")
            service.edits().images().deleteall(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                imageType="icon"
            ).execute()
            icon_media = MediaFileUpload(ICON_PATH, mimetype="image/png")
            service.edits().images().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                imageType="icon",
                media_body=icon_media
            ).execute()
            print("Store icon updated successfully.")

            # C. Update Feature Graphic
            print("Updating feature graphic...")
            service.edits().images().deleteall(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                imageType="featureGraphic"
            ).execute()
            fg_media = MediaFileUpload(FEATURE_GRAPHIC_PATH, mimetype="image/png")
            service.edits().images().upload(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                imageType="featureGraphic",
                media_body=fg_media
            ).execute()
            print("Feature graphic updated successfully.")

            # D. Update Phone Screenshots
            print("Updating phone screenshots (5 images)...")
            service.edits().images().deleteall(
                packageName=PACKAGE_NAME,
                editId=edit_id,
                language=lang,
                imageType="phoneScreenshots"
            ).execute()
            for idx, ss_path in enumerate(SCREENSHOTS, start=1):
                ss_media = MediaFileUpload(ss_path, mimetype="image/png")
                service.edits().images().upload(
                    packageName=PACKAGE_NAME,
                    editId=edit_id,
                    language=lang,
                    imageType="phoneScreenshots",
                    media_body=ss_media
                ).execute()
                print(f"  Uploaded screenshot {idx}/5: {os.path.basename(ss_path)}")
            print("Screenshots updated successfully.")

        # 5. Commit the edit transaction
        print("\nCommitting changes to Google Play Console...")
        commit_response = service.edits().commit(
            packageName=PACKAGE_NAME,
            editId=edit_id
        ).execute()
        print(f"Changes committed successfully! Edit ID: {commit_response.get('id')}")

    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        # Try to delete failed edit
        try:
            service.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            print(f"Deleted failed edit: {edit_id}")
        except Exception:
            pass
        sys.exit(1)

if __name__ == "__main__":
    main()
