---
inclusion: always
---

# Engine quality bar

Target: a page-turn engine that never loses a turn, never leaks, never draws
garbage, and stays at display refresh rate. Every change is measured against
these invariants; tests enforce them as properties, not as single examples.

## Invariants (enforced by tests)

| # | Invariant | Enforced in |
|---|-----------|-------------|
| I1 | `currentIndex` is inside the book at all times; `itemBuilder` is never asked for an index outside `[0, itemCount)` | `page_flip_state_controller_model_test`, `page_flip_widget_session_test` |
| I2 | Lifecycle balance: `onFlipStart - onFlipEnd == (isBusy ? 1 : 0)`; refused navigation reports nothing | model + session + `page_flip_turn_ownership_test` |
| I3 | One owner per turn: a finger, a tap flip, or a jump; the others are refused while `isBusy` | model + ownership |
| I4 | The outcome decided at release is the outcome that lands; a settle moves monotonically toward it; a commit moves exactly one page | model |
| I5 | Idle means reset (progress 0, not dragging); no finger means content is not pointer-blocked | model + session |
| I6 | Snapshot handles: reachable ⇒ alive, removed ⇒ disposed, no handle shared by two slots, zero images leaked per session | `pre_render_manager_lifetime_test`, `page_flip_widget_session_test`, `page_flip_foldable_mode_switch_test` (soak) |
| I7 | Geometry and painting produce only finite coordinates for any size ≥ 0, any progress, any touch | `rendering_robustness_test` |
| I8 | `PageFlipConfig.normalized` is total (any input), in range, and idempotent | `rendering_robustness_test` |
| I9 | After a change of the viewport's shape (fold, unfold, rotation) the capture window is replaced within a few frames, a debounced request never discards a readback already in flight, and a turn that starts after the change draws no page out of shape (out-of-shape pages are retaken synchronously at its start); a resize never flushes images (stale ones stay until replaced) and leaves a turn in the air its images; a spread-mode switch resets the cache, recaptures at once and ends a turn in the air (`onFlipEnd` once, no `onPageChanged`); after a session every kept snapshot has the book's shape | `page_flip_foldable_test`, `page_flip_foldable_mode_switch_test`, `pre_render_manager_readback_test`, `snapshot_resize_policy_test`, `page_flip_structural_change_test`, `page_flip_widget_session_test` |

## Testing rules

- Prefer seeded model-based / property tests over single scenarios. A new
  state or input must be added to the random generators, not just to one test.
- Every bug fix lands with a test that fails without the fix.
- Expected values come from the specification of the behaviour, never from
  running the code and copying its output.
- Keep suites deterministic: fixed seeds, fake time, no real timers.

## Known gaps (next work)

- A replaced snapshot can be disposed while the last-built `PageFlipPainter`
  still references it; a repaint without a rebuild would draw a freed image.
  Fix by giving image ownership to a render object (single-renderer work).
- A turn in the air when the viewport changes shape (not the spread mode)
  keeps drawing its old, stretched images until it ends: while a finger holds
  it, and then through the whole settle (up to the configured duration). The
  swap waits for `onFlipEnd` so the painter never receives a disposed image.
  Cancel such a turn, or fix it together with the render-object image
  ownership above.
- Immediate recapture compares consecutive sizes. Steps above 10% in a single
  frame (a keyboard over a short landscape viewport, a fast window drag at a
  low frame rate on web or desktop) retake the window once per such frame
  (measured: 8 frames of 12% steps gave 24 readbacks instead of 3); a slow
  change made of small steps is retaken once when it stops.
- The engine does not read `MediaQuery.displayFeatures` (hinge, posture). The
  host picks single page or spread from the window shape (README, Foldables).
  Flutter fills that list only on Android, so a shape rule is the only one that
  also covers iPhone Duo.
- Foldable behaviour is verified by simulating the display shapes of the
  Galaxy Z Fold8, Fold8 Ultra and iPhone Duo; it has not run on the devices.
- No frame-time regression gate yet (profile-mode `integration_test` timeline).
- RTL reading direction is not implemented (keyboard / wheel input and reduced
  motion landed in 3.1.0).
