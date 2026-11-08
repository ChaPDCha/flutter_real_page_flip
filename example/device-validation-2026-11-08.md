# Single-page printed-content validation — 2026-11-08

## Change

The single-page painter now retains the moving sheet's content texture on all
performance profiles. Medium and low previously omitted that mesh until the
late settle phase. They retain their existing mesh density: 12 segments / 2
columns for medium, and 8 segments / 1 column for low. The default back-content
opacity remains 0.35; text seen through the back of the paper is intentionally
fainter than text on a flat page.

## Physical device

- Samsung SM-A505N, Android 11, 1080 × 2340, device pixel ratio 2.625.
- Profile-mode Flutter build, Impeller OpenGLES backend, single-page layout.
- Tested both medium and low with the fixture's default opacity and settle
  reveal enabled. System reduced motion was off and system settings were not
  changed for the test.
- Installed the separate `app.realbook.reader.devicecheck` app. The installed
  reader application and its data were preserved. The validation app was
  stopped after recording to release its keep-screen-on window.

### Held intermediate frames

Actual touchscreen DOWN / MOVE / UP events drove the book. Each frame was
captured while holding the finger at the recorded progress. A paragraph-only
probe was inset inside the curved moving sheet, excluding stationary pages,
header, footer, paper, shadows, and horizontal divider rules. Colored glyphs
made text detectable even after the default 35% back-content dimming.

| Profile | Direction | 25% glyph pixels | 50% glyph pixels | 75% glyph pixels |
| --- | --- | ---: | ---: | ---: |
| medium | Forward | 1,475 | 4,303 | 3,251 |
| medium | Backward | 3,251 | 4,303 | 1,475 |
| low | Forward | 1,144 | 3,282 | 2,536 |
| low | Backward | 2,536 | 3,282 | 1,144 |

Four additional 25% frames preceded forward/backward returns on both profiles.
All 16 sampled intermediate frames contained printed glyphs on the moving
sheet. The screenshots and a contact sheet were visually inspected. Probe
positions deliberately contain source text; a narrow strip near a turn's
endpoint can legitimately show the page's unprinted outer margin.

### After pointer release

| Profile | Case | Settle duration | Page outcome | Moving layer retained |
| --- | --- | ---: | --- | --- |
| medium | Forward complete | 288 ms | 3 → 4 | Yes |
| medium | Backward complete | 289 ms | 4 → 3 | Yes |
| medium | Forward return | 258 ms | 3 → 3 | Yes |
| medium | Backward return | 263 ms | 3 → 3 | Yes |
| low | Forward complete | 274 ms | 3 → 4 | Yes |
| low | Backward complete | 278 ms | 4 → 3 | Yes |
| low | Forward return | 264 ms | 3 → 3 | Yes |
| low | Backward return | 253 ms | 3 → 3 | Yes |

All eight cases reached their expected page. Every sampled nonterminal settle
frame kept the moving layer active. The video review also included a low-profile
return at 90 ms after release, with printed text still visible on the sheet.

### Evidence

Local artifacts are under `build/device-content-20261108/`:

- `device-verification.json`: actual drag metadata, paragraph probe bounds and
  glyph counts, release results, recording hashes, and decoded frame counts.
- `intermediate-text-contact-sheet.png`: medium/low, forward/backward, 25/50/75%.
- `medium-*-25.png`, `medium-*-50.png`, `medium-*-75.png` and corresponding low
  screenshots; `*-text.png` files hold the paragraph probes.
- `medium-logcat.txt`, `low-logcat.txt`, `medium-content.mp4`, `low-content.mp4`.

Recordings were received using ordinary `adb pull`. Screenrecord uses variable
frame rate, so its average encoded frame rate is not an application performance
measurement. This validation establishes content visibility and turn lifecycle
on this device; it is not an FPS benchmark or physical iOS verification.

## Automated coverage

`test/effects/single_page_content_visibility_test.dart` renders ready printed
textures directly on the moving sheet, without a host app or an asynchronous
capture cache. It checks 144 representative frames: three performance profiles,
two paper themes, two directions, both settle-reveal settings, and progress
10/25/50/75/84/90%.

The single-page layer goldens now supply the snapshot map actually consumed by
the moving sheet. Previously, they omitted that map and therefore accepted an
empty flap. Default medium and explicit low middle-frame goldens now include
printed content.
