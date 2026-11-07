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
the only ledger that can catch a regression in behaviour, and it has two
open gaps as of this round (C1, C7); C3 closed this round and C11's
mid-shred-write half closed this round too (see this file's own "Holes"
section below).

## Extra

331 census rows across the port, outside the parity count. Welcome, not
parity work, and the two new specs added in `4c759f3` are among them:

| File | Cases | What they drive |
|---|---:|---|
| `test/drive_main_window.rb` | 41 steps, 205 checks (+1 step/check this round) | the whole app under a real main loop — see the file's own header comment for the 11-component breakdown, plus the new C3 step |
| `spec/window_spec.rb` | 25 (+1 this round) | widget tree, sizes, both menus, drop target, `open_file`/`open_files` branches **(`open_files` now async, see C3)**, clear, completion callbacks, `request_exit`, **and a new C3 regression spec** |
| `spec/app_spec.rb` | 18 (+1 this round, +3 vs. the audit before last) | actions, accelerators, About fields, `--version`/`-v`, the C4 window-targeting race, the C10 `open`-vfunc argv contract, **and a new regression spec**: `action_open_folder`'s own window-targeting |
| `spec/file_row_spec.rb` | 12 | title/subtitle, revealer states, popover, `launch_shredding`/`shredding_abort`, a failed shred's row |
| `spec/translation_spec.rb` | 11 | the bound domain, every language in `LINGUAS` built, `POTFILES`, every msgid, mnemonics, U+2026, a live German-locale round trip |
| `spec/data_files_spec.rb` | 11 | the two parity rows above, plus the C8/C9 regression specs |
| `spec/corrupt_spec.rb` | 8 (+1 this round) | the five patterns, a regular/zero-byte file, a folder tree, cancel, wait, an unlistable directory (C5), **and a new regression spec**: a write failing partway through a pass |
| `spec/progress_paintable_spec.rb` | 6 | box size, redraw, radius/line width, sweep, clamping |
| `spec/progress_info_popover_spec.rb` | 5 | the bar and all four text states |
| `spec/shortcuts_dialog_spec.rb` | 5 | section, action-named items, accelerator-bound actions |
| `spec/exit_dialog_spec.rb` | 3 | both responses, mnemonics |

## Holes in the extra coverage that still let a gap survive

A component no check exercises is unverified, not done. Three of the four
holes this document named are closed this round; re-stated with that
status rather than silently dropped:

* **CLOSED this round — `action_open_folder`'s window-targeting is now
  driven.** `spec/app_spec.rb`, "#action_open_folder targets the window
  active when the dialog was opened", is the C4 regression spec's own
  shape (`spec/app_spec.rb:168`) repeated against
  `select_multiple_folders`/`select_multiple_folders_finish` instead of
  `open_multiple`: two windows, focus switched mid-dialog, the folder's
  files asserted to land in the window the dialog was opened from. Run
  this round: passes.
* **CLOSED this round — a write failing mid-shred is now driven.**
  `spec/corrupt_spec.rb`, "when a write fails partway through a pass",
  stubs `File.open` to yield an object whose third `write` raises
  `Errno::EIO`, landing the failure after some of the pass's writes have
  already gone out — distinct from the existing C5 spec, which covers an
  unlistable *directory* before shredding even starts, not a write
  failing mid-pass on an open file. Asserts the run stops, reports
  `step`'s error message, and leaves the file in place. Run this round:
  passes.
* **CLOSED this round — a check now opens enough files at once to
  observe gap C3 directly, because C3 itself closed.** `spec/window_spec.rb`
  (40 files) and `test/drive_main_window.rb` (60 files, new driver step
  "opening many files at once does not freeze the main loop (C3)") both
  assert the row count is observed to grow across more than one turn of
  the main loop rather than jumping straight from zero to the full count —
  the behaviour that was previously only read off the source. See
  `component-parity.md`'s own C3 section for the implementation.
* **Still open — no check exercises `--help` output.** Gap C1 — the
  missing `GOptionEntry` registration — is unchanged this round (see
  `component-parity.md`'s C1 section and `KNOWN_LIMITATIONS.md`); adding a
  `--help` assertion without the registration to back it would only prove
  the absence, not close the gap, so it stays named here rather than
  faked with a weaker check.

Two gaps a previous round's coverage genuinely closed (the German-locale
check, and the five A13 regression specs) are not re-litigated above;
they are recorded closed in `component-parity.md` and
`accountability-ensurance.md`.

## Rules check

* No test was lowered to pass; nothing is commented out. The appstreamcli
  failure is reported as a failure, not weakened to a warning-only check or
  skipped.
* No upstream test was merged into another.
* No `n/a`, no `not applicable`.
* The previous report's framing ("2/2 ported, 0/2 executed") is updated on
  evidence, not carried forward out of inertia: both now execute, as a live
  run in this audit confirms.

## Independent re-audit, this round (HEAD `f0a5135`)

Re-confirmed upstream has no `test/`/`tests/` directory
(`git ls-tree -r --name-only origin/main | grep -i test` → empty) and its
only two tests are the `meson.build` `test()` calls already named above —
re-read directly from `git show origin/main:data/meson.build`, not from
this file's own earlier count. Both ran live this round:
`desktop-file-validate` passes, `appstreamcli validate --no-net` fails on
`developer-id-invalid io.github.ADBeveridge` — confirmed against
upstream's own `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in`,
which declares `<developer id="io.github.ADBeveridge">` while the app id
itself is `com.github.ADBeveridge.Raider`: upstream's own id mismatch, not
something the port introduced. `rspec` (101 examples, 1 failure) and
`test/drive_main_window.rb` (204/204, `DRIVE OK`) both reproduce the exact
counts this document already stated.

The holes this document lists under "Holes in the extra coverage" (no
check drives `action_open_folder`'s window targeting, no check fails a
write mid-shred, no check exercises `--help`, no check opens enough files
to observe gap C3's freeze) were all still holes as of that round —
grepped `spec/` and `test/drive_main_window.rb` that round for each
behaviour named and found no new coverage for any of them since this
document was last written.

## Round 2 (this round): three of the four holes closed

Re-run live: `rspec` → **104 examples, 1 failure** (the same
`appstreamcli developer-id-invalid` row; +3 vs. the previous round's
101 — one each for the three holes closed below).
`test/drive_main_window.rb` → **205 of 205 checks passed, `DRIVE OK`**
(+1 vs. the previous round's 204 — the new C3 driver step).

Of the four holes named above: `action_open_folder`'s window-targeting,
a write failing mid-shred, and opening enough files to observe C3 are
now each driven by a named spec or driver step — see the "Holes in the
extra coverage" section above, which carries the per-hole detail rather
than repeating it here. The fourth, `--help` output, is unchanged and
remains open: it is gated on gap C1 (`GOptionEntry` registration), which
this round did not attempt to close, so asserting on `--help` text now
would only assert on the absence the gap already documents, not add
coverage that could catch a real fix regressing.

## Round 3 (this round): re-run live, counts unchanged

`rspec` → **104 examples, 1 failure** (same `appstreamcli
developer-id-invalid` row, upstream's own data defect, not a port
regression). `test/drive_main_window.rb` → **205 of 205 checks passed,
`DRIVE OK`**, 11 components. Both numbers match the previous round's
report exactly, measured by actually running the commands this session,
not read off this file. `git log --oneline -1 -- lib/ exe/ test/ spec/`
still points at `c6b52d7`; no test or driver file changed since the
previous audit, so no new hole could have opened and none of the three
holes closed in that commit (`action_open_folder` targeting, mid-shred
write failure, C3's many-files-at-once check) could have regressed
silently — each was re-run live above as part of the same two commands.

The upstream test bijection is still **2/2 ported, 2/2 executed** (one
passing, one failing on upstream's own metainfo defect). The fourth hole
named in the "Holes in the extra coverage" section — no check exercises
`--help` output — is still open and still correctly gated on gap C1,
which was not touched this round.
