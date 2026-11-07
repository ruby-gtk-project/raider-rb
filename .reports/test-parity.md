# Test parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `485859999051aba397cdc0ae04fe530baad81c9b` |
| Re-run this audit | `git diff 4c759f3..HEAD -- lib/ exe/ test/ spec/` is empty — the two commits since then (`a4cb8d0`, `4858599`) touch only `PORTING.md` and `.reports/component-inventory.md`. Both the drive run and the spec suite were re-run live this round (below) and reproduce the exact same counts. |
| Upstream tests | **2** |
| Ported (a named port test exists) | **2** |
| Ported **and executed** | **2** — changed this audit, was 0 |
| Gaps | **0** in the bijection; see "The port has no inherited safety net" below for what that 0 does not mean |
| Spec command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` |
| Spec result, this audit (run live) | **101 examples, 1 failure** |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |
| Drive result, this audit (run live) | **204 of 204 checks passed, `DRIVE OK`**, 40 steps, 11 components |

## Censusing upstream

Upstream has no `test/`/`tests/` directory and no unit-test framework. Its
only tests are registered through meson's `test()` in `data/meson.build`,
guarded by `find_program(…, required: false)`:

```
data/meson.build:12  test('Validate desktop file', desktop_utils, args: [desktop_file])
data/meson.build:27  test('Validate appstream file', appstreamcli, args: ['validate', '--no-net', appstream_file])
```

The upstream suite is **2**, not 0.

## Suite: data (2 tests)

| # | Upstream test | Purpose | Port test | State | Result this audit |
|---|---|---|---|---|---|
| 1 | `data/meson.build:12` `Validate desktop file` | the merged desktop entry passes `desktop-file-validate`, so the app appears in a launcher | `spec/data_files_spec.rb:46` → `:47` | **ported, executed** | **passed** |
| 2 | `data/meson.build:27` `Validate appstream file` | the merged metainfo passes `appstreamcli validate --no-net`, so software centres accept the listing | `spec/data_files_spec.rb:59` → `:60` | **ported, executed** | **failed** |

### Both rows now execute, for the first time in this port's history

`flake.nix`'s dev shell gained `desktop-file-utils` and `appstream` in
commit `4c759f3`. Before that commit, both examples were marked `pending`
("validator not installed") and asserted nothing — a prior round's report
(`ad33dea`) claimed they had "actually run and passed," which was false at
the time it was written (`.rspec_status` showed `pending`, not `passed`,
for both). That specific false-green claim is now moot because the
examples genuinely run, but the fact that it was made at all is recorded in
`accountability-ensurance.md`.

Measured this audit, running the actual spec suite rather than reading
`.rspec_status`:

```
1) DataFiles Validate appstream file passes appstreamcli validate --no-net
   W: com.github.ADBeveridge.Raider:152: developer-id-invalid io.github.ADBeveridge
   I: com.github.ADBeveridge.Raider:155: nonstandard-gnome-extension kudos
   ✘ Validation failed: warnings: 1, infos: 1, pedantic: 2
```

This failure is upstream's own data: `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in:24`
in the port is byte-identical to `git show origin/main:data/com.github.ADBeveridge.Raider.metainfo.xml.in.in:24`
(confirmed by diff), and `appstreamcli` flags the *upstream* id format, not
anything the port changed. Row 2 is **ported and executed**, and its result
is a real, reproducible failure the port inherited rather than introduced.
Calling this row "passing" would be the false green this skill's own rules
forbid; calling it a *port* bug would be equally wrong. It is reported
exactly as it runs: ported, executed, failing, upstream's defect.

The mapping is a bijection: each upstream `test()` title is kept verbatim
as the port's example description, the port builds the same merged output
with the same `msgfmt --desktop`/`msgfmt --xml` invocation, and runs the
same validator with the same arguments including `--no-net`.

## The port has no inherited safety net

Both of upstream's tests validate generated metadata. Not one line of
`src/corrupt.c`, `src/raider-window.c`, `src/raider-file-row.c`,
`src/raider-progress-paintable.c` or `src/raider-application.c` is covered
by anything upstream wrote. **Closing both rows (which is now done) buys
this port no behavioural coverage of its own** — `component-parity.md` is
the only ledger that can catch a regression in behaviour, and it still has
three open gaps (C1, C3, C7) plus one uncovered sub-case (C11's
mid-shred-write half).

## Extra

331 census rows across the port, outside the parity count. Welcome, not
parity work, and the two new specs added in `4c759f3` are among them:

| File | Cases | What they drive |
|---|---:|---|
| `test/drive_main_window.rb` | 40 steps, 204 checks | the whole app under a real main loop — see the file's own header comment for the 11-component breakdown |
| `spec/window_spec.rb` | 24 | widget tree, sizes, both menus, drop target, `open_file` branches, clear, completion callbacks, `request_exit` |
| `spec/app_spec.rb` | 17 (+2 vs. last audit) | actions, accelerators, About fields, `--version`/`-v`, **and two new regression specs**: the C4 window-targeting race and the C10 `open`-vfunc argv contract |
| `spec/file_row_spec.rb` | 12 | title/subtitle, revealer states, popover, `launch_shredding`/`shredding_abort`, a failed shred's row |
| `spec/translation_spec.rb` | 11 (rewritten, same count) | the bound domain, every language in `LINGUAS` **built, not excluded**, `POTFILES`, every msgid, mnemonics, U+2026, a live German-locale round trip (**new**) |
| `spec/data_files_spec.rb` | 11 (+2 vs. last audit) | the two parity rows above, plus **two new regression specs**: the exact developer-id casing (C8) and the metainfo `<image>`/screenshot pairing (C9) |
| `spec/corrupt_spec.rb` | 7 (+1 vs. last audit) | the five patterns, a regular/zero-byte file, a folder tree, cancel, wait, **and one new regression spec**: an unlistable directory prints the listing diagnostic and never calls `rmdir` (C5) |
| `spec/progress_paintable_spec.rb` | 6 | box size, redraw, radius/line width, sweep, clamping |
| `spec/progress_info_popover_spec.rb` | 5 | the bar and all four text states |
| `spec/shortcuts_dialog_spec.rb` | 5 | section, action-named items, accelerator-bound actions |
| `spec/exit_dialog_spec.rb` | 3 | both responses, mnemonics |

## Holes in the extra coverage that still let a gap survive

A component no check exercises is unverified, not done. Re-stated rather
than dropped now that some of these closed:

* **`app.open-folder`'s window-targeting is still never driven.** The new
  C4 regression spec (`spec/app_spec.rb:168`) drives `action_open` only.
  `action_open_folder` shares the same `active_port_window` call
  (`lib/main.rb:237-248`) but has no regression test of its own.
* **No check fails a write mid-shred, still.** `spec/corrupt_spec.rb`'s new
  C5 spec covers an unlistable *directory*; a file that opens for writing
  and then fails partway through a pass has never been driven, before this
  round or after it.
* **No check exercises `--help` output.** Gap C1 — the missing
  `GOptionEntry` registration — could regress in either direction (it
  could also get silently "fixed" by a change that doesn't actually wire
  `--help` correctly) and nothing would notice.
* **No check opens enough files at once to observe gap C3's UI freeze.**
  Read off the source on both sides, not reproduced live.

Two gaps this round's coverage genuinely closed (the German-locale check,
and the five A13 regression specs) are not re-litigated above; they are
recorded closed in `component-parity.md` and `accountability-ensurance.md`.

## Rules check

* No test was lowered to pass; nothing is commented out. The appstreamcli
  failure is reported as a failure, not weakened to a warning-only check or
  skipped.
* No upstream test was merged into another.
* No `n/a`, no `not applicable`.
* The previous report's framing ("2/2 ported, 0/2 executed") is updated on
  evidence, not carried forward out of inertia: both now execute, as a live
  run in this audit confirms.
