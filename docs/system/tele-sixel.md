# Tele Sixel: source, fixes, and upstream contribution

Verified 2026-10-24. Installed `~/.local/bin/tele` reports
`1.11.13+sixel.369c21e`. Quit and reopen Tele to load the corrected binary;
existing processes were not stopped or remotely controlled.

## Source and PR

- Upstream PR: [Sixel photo previews and album rendering, #318](https://github.com/sorokin-vladimir/tele/pull/318).
- Published source: `kmanisk:feat/sixel-images`, head `a7a0f3a`, including
  current upstream `main` at `6aa6cf9`. The worktree `~/Projects/tele-sixel`
  is clean on this same feature branch. The resize and sidebar fixes are now
  published in #318; history was preserved with a merge from upstream main.
  No upstream branch was pushed and the PR was not merged.
  PR #320 remains closed as superseded by #318.
- Installed source: `~/Projects/tele-sixel-stable`, branch
  `local/sixel-polish-v1`, head `369c21e`. This separate worktree backports the
  corrections onto the original saved source baseline `84bb75f`, rather than
  deploying current upstream main. Both candidate and installed-source working trees are clean.

The old binary's display label was `1.11.13+sixel`; the recorded source base
has a beta tag. Source contents were checked directly rather than inferring
compatibility from that label: all 715 files outside the original Sixel change
matched the saved `~/.local/src/tele-work` tree exactly. The installed build
preserves the legacy display label with a patch revision suffix. The original
source, patch, archive, and notes remain unchanged under `~/.local/src`.

## Final consolidated publication

The contributor authorized publication after confirming manual testing in the
real Tele, Foot and Sway session. PR #318 now contains the complete Sixel
implementation and its required geometry, Unicode, text-boundary, cleanup and
resize fixes. There is one active Sixel PR; #320 is closed and superseded.

Current upstream added translated-document anchor checks. Final integration
updated the Sixel media sections and configuration examples in Russian and
Simplified Chinese, corrected the settings help, and placed the new feature
under Unreleased. No new rendering or architecture changes were made during
finalization.

The exact published head passed the full race-enabled Go test suite, focused
regressions, vet, golangci-lint v2.15.0, formatting, module consistency,
whitespace checks and an application build. Native Foot/Sway checks passed
10 sidebar and 35 Sixel scenarios with the race detector. The private harness
waits for width-negotiation redraw and modal encoding, and resamples at most
twice if frame metadata changes during screenshot capture. A full Nix build
was not available locally; the modules and flake match the verified vendor hash.

GitHub reports `MERGEABLE`, with merge state `UNSTABLE`; no CI checks are
reported. These are GitHub observations, not a CI success claim. The single
[follow-up comment](https://github.com/sorokin-vladimir/tele/pull/318#issuecomment-6376898850)
records the consolidated fixes and validation. Final evidence is in
`~/.local/state/tele-pr-final-audit/result.json`. The installed preserved-baseline
binary stays at `1.11.13+sixel.369c21e`.

The sections below record earlier validation and publication stages; their
unpublished-state notes are historical.

## Screenshot findings and fixes

Two images in one row are the intentional album grid. Detached strips and
pixels beyond a tile are defects. A synthetic full-TUI reproduction confirmed
that an album badge moved the first-row marker without reducing its width.
Badge cropping now updates the image's horizontal origin and width together.

Additional fixes cover stale asynchronous encodes and queued raw writes,
placement removal, overlay transitions, pixel-size cache invalidation, and
partial final six-pixel bands. A raster retains its exact cell footprint;
rounding its height up could paint into the following row. Encoding runs one
job at a time per state. Unchanged frames do not trigger repaint loops.

Cleanup is serialized with raw writes. A zero-width SGR reset changes the view
identity after a clear because Bubble Tea 2.0.6 can otherwise skip a pending
renderer erase when the view text is unchanged. Idle frames remain identical.
The earlier marker-parser and stacked-placement fixes are retained.

## Validation and limits

Both the upstream candidate and local backport passed the full Go test suite,
`go vet ./...`, golangci-lint v2.15.0 with zero issues, gofmt, and Git whitespace
checks. These are the three commands required by `mise run check`, executed
directly. No system tooling package was installed.

A private synthetic fixture exercised the actual Bubble Tea UI under isolated
headless Sway/Foot with Go's race detector. Screenshot comparisons passed for
albums, a single image, closing/reopening the chat, modal open/close, and rapid
album/single/empty transitions. A fixture mistake that initially closed only
the header was corrected to clear messages as the real close action does.
Additional renderer checks passed clipping, covered-cell erasure/restoration,
output resize, font zoom from 10x23 to 14x34 pixel cells, and partial-band bounds.
The temporary compositor and terminal were shut down after each run.

No new authenticated Telegram workflow or long-session memory test was run.
mlterm and WezTerm were not tested. GitHub reported no CI checks on the PR at
the final status query; local checks passing is not a CI or merge claim.
The PR contains no account data, private screenshots, binaries, or audit logs.

## Unicode alignment follow-up

A title containing an ASCII digit, variation selector, and enclosing keycap
reproduced the sidebar shift. The old Ultraviolet decoder consumed the digit
as one cell and dropped the combining suffix, while the grapheme-based layout
reserved two. Pinning the upstream cluster/resize fix `d38ea0f8aa5c` corrects
the reproduced grapheme path. The change stays in the window renderer; owner,
session, protocol, database, and authentication behavior are unchanged.

Foot also exposed a startup race: width negotiation could finish after the
first frame without invalidating it. A supported Unicode mode reply now queues
one clear and redraw. Sixel forgets the erased placements, restores an open
photo modal, and invalidates old queued writes. Unsupported and repeated reports do not request another clear.
The installed backport preserves the original source baseline and credentials.

Current base, Sixel, and local-backport candidates passed full Go tests, vet,
and golangci-lint with zero issues. Race-enabled native Foot screenshot checks
passed 13 scenes at that stage, including scroll up/down and resize,
asserting border columns and exact image bounds. The old dependency failed the
native border check and the cell-buffer regressions. An early apparent stalled
paint was a fixture sampling an in-flight encode; its completion is now awaited.
The Nix vendor hash was recalculated after reproducing the old hash; a full Nix
build was not possible because Nix is absent.

Kitty still shows a wcwidth/grapheme-width disagreement and its native visual
check did not pass. General terminal width calibration, tracked upstream in
issues 235, 289, and 313, is not solved by this change. No all-terminal or merge
claim is made. The maintainer's positive reply still leaves review pending.

The shared base candidate remains in `~/Projects/tele-layout-fix`, branch
`fix/unicode-pane-alignment`, head `0ecd6d4`. At the user's request, review is
consolidated into [PR #318](https://github.com/sorokin-vladimir/tele/pull/318).
It contains the base candidate's commits as ancestors; no history was rewritten.
[PR #320](https://github.com/sorokin-vladimir/tele/pull/320) is closed as
superseded. The maintainer has one active contribution to review. Local checks
are not a CI or maintainer acceptance claim.

## Remaining screenshot symptoms: bounded metadata and joined symbols

Long attachment labels, file albums, sender names and reaction rows could
widen a message beyond its pane. An old-code regression rendered a file label
at 300 cells in a 30-column pane and an assembled frame at 344 cells for a
140-column terminal. Labels now truncate within the pane, while bodies keep
wrapping. Playing voice waveforms resample into the available cells and retain
the playback time. Grapheme-based plain-text truncation handles keycaps without
the ASCII fast-path undercount in the previous truncators.

A separate defect occurred even with bounded labels: the unqualified joined
sequence `U+1F441 U+200D U+1F5E8` measures one cell in the width library and two
in an actual Foot cursor-position report, even with Unicode mode 2027 enabled.
A title visible in the sidebar therefore shifted the remainder of that row,
including a different open chat and its images. A private native fixture
reproduced this failure before the fallback.

Concord was inspected at `b312f1899cd6fb96847e9973d080e2e415d05aff` as a
reference. Its `src/tui/text.rs` uses grapheme-aware truncation and a broader
`?` display fallback for narrow symbols likely to render wide. Its Ratatui
widgets use bounded rectangles, and `src/tui/runtime/placement.rs` tracks image
positions and clears moved or removed placements before redrawing.
Tele retains its architecture and applies a narrower fallback at the final
view boundary: one-cell joined clusters containing at least two Unicode
symbols display as `?`. This preserves composed cell widths and avoids touching
stored names, messages or copied text. Qualified two-cell symbols, keycaps,
combining accents, ANSI styling, hyperlink targets and opaque
image markers remain intact. No terminal configuration or authentication changed.

Both final Sixel candidates passed full Go tests, vet, golangci-lint v2.15.0
with zero issues, gofmt and whitespace checks. Native race-enabled Foot tests
passed all 17 scenes with mixed problematic joined-symbol and keycap titles,
including scroll, transitions, modal width reset, resize, long files and a
return to albums. Checks assert all visible pane edges, exact image bounds and
no stale pixels; inner edges intentionally covered by the modal are excluded.
General Kitty wcwidth/grapheme disagreements remain outside the verified fix.
No new authenticated Telegram workflow or mlterm/WezTerm test was run.

Prior private evidence, PR bodies and installation manifest:
`~/.local/state/tele-overflow-audit/`. The older rendering-audit manifests are
historical. Restore the binary from before the joined-symbol fallback with:

```sh
install -m755 ~/.local/state/tele-overflow-audit/backups/tele-before-joined-fallback ~/.local/bin/tele
```

Then reopen Tele. The backup before the bounded-metadata correction is
`~/.local/state/tele-overflow-audit/backups/tele-before-overflow`.

## Scratchpad/fullscreen resize follow-up

The local resize candidate invalidates Sixel placements on every window-size
notification, including unchanged image cells. Old raw writes cannot land after
a resize. Resize bursts wait for a 90 ms quiet period before clearing and
painting; only one inline paint tick is pending at a time, existing encodings
remain reusable, and cancelled encodes re-arm the latest viewport without an
idle retry loop. Obsolete encodes stop before processing additional images.

Cell-size replies now invalidate block-art caches and memoized message heights,
in addition to the Sixel encoding cache. The failing regression reserved 13
rows while rendering 19 cached rows; an actual Foot font-zoom fixture also
reproduced 13 cached rows against a 12-row box before the fix.

An open photo modal now recomputes its box when the window shrinks. The native
fixture reproduced a 44-row raster overflowing a 32-row terminal and scrolling
the TUI. Old modal writes are rejected after resizing, closing, font changes or
clearing. Resizing defers encoding to the latest modal geometry. Palette
construction now starts with deterministic histogram ordering; repeated encodes
previously produced different colors after a cache invalidation.

Both final candidates passed full Go tests, vet, golangci-lint v2.15.0 with zero
issues, formatting and whitespace checks. Race-enabled native Bubble Tea/Foot
checks passed 35 scenarios per build: floating and scratchpad windows,
fullscreen round trips, height-only changes, rapid toggles, font zoom/reset,
scrolling, single images, albums, long captions/files, and modal resize/reset/
close. Complex-image pixels are compared exactly across equal geometries;
patterned images catch duplicated bands that solid-color fixtures could miss.
The fixture runs under a private headless Sway compositor and leaves desktop
configuration unchanged. No new authenticated Telegram workflow was run.

Current evidence and installed hash: `~/.local/state/tele-resize-audit/`.
The public candidate is a local commit on `fix/sixel-resize`; consolidation of
the previous work remains in #318. At the user's request, publishing the new
resize correction is deferred. Restore the previous `01c5188` binary with:

```sh
install -m755 ~/.local/state/tele-resize-audit/backups/tele-before-resize ~/.local/bin/tele
```

Then reopen Tele. Older evidence and rollback paths below remain historical.

## Sidebar conjunct-width follow-up

The remaining no-chat sidebar screenshot exposed a second text-width mismatch.
An isolated Foot cursor-position report advanced two cells for Malayalam,
Devanagari and Bengali virama conjuncts that the width library counts as one.
The Malayalam title visible in the sidebar measured 27 terminal cells against
26 layout cells. A native fixture reproduced a shifted border during resizing;
a focused word-width regression failed before the fix.

Display strings now insert a zero-width non-joiner before the second consonant
of a narrow virama conjunct, before truncation, wrapping or border measurement.
Letters remain present, but conjunct ligatures may appear in non-joining forms.
Entity offsets are calculated on the original input; stored text, copy targets,
ANSI escape payloads and hyperlink targets are preserved. This uses the
existing x/text Unicode normalization tables, with no dependency version or
Nix vendor hash change. No renderer or authentication redesign was added.

Both source trees passed full Go tests, vet, golangci-lint v2.15.0 with zero
issues, formatting and whitespace checks. Race-enabled native Foot checks
passed 10 sidebar scenarios and 35 Sixel scenarios per tree, including reorders,
unread updates, a toast, floating/fullscreen resizing, albums and photo modals.
The stable sidebar fixture needed an initial window-size update before entering
the main screen; the Sixel fixture also needed to await modal encoding before
sampling pixels. Those fixture corrections are recorded with the evidence.
The stable tree retains an unrelated pre-existing `go mod tidy -diff` proposal
to classify Cobra as direct; no module version changes were introduced.

Evidence and the current installation manifest are in
`~/.local/state/tele-sidebar-audit/`. The installed build is
`1.11.13+sixel.369c21e`, SHA256
`d2a585ed34915b3fb7f73b47f506b2f94c7941d82f1844cc4fc60f840af87aaa`.
Existing Tele processes must be restarted. Both commits remain local;
PR #318 is still open at `1171578`. No new authenticated Telegram workflow
was run, and the earlier Kitty width-policy limitation remains unverified.

Restore the previous `132cc2a` binary, then reopen Tele:

```sh
install -m755 ~/.local/state/tele-sidebar-audit/backups/tele-before-sidebar ~/.local/bin/tele
```

## Artifacts and rollback

Private evidence: `~/.local/state/workstation-audit/20261023/`.
`tele-install.json` records the installed hash, source revision, and backup.
`tele-upstream-visual/` retains upstream screenshots/results;
`tele-terminal-results.json` records the local backport's terminal checks.
`test_tele_terminal.py` and `tele-terminal-fixture.go.txt` reproduce the private
terminal fixture. Temporary downloaded tools and superseded build outputs were
removed after validation.

Restore the previous binary, then reopen Tele:

```sh
install -m755 ~/.local/state/workstation-audit/20261023/backups/.local/bin/tele-before-polish ~/.local/bin/tele
```

See the [workstation audit](workstation-audit-2026-10-23.md) for earlier system
changes and their independent rollback procedures.
