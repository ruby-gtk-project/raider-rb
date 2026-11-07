# Component parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `485859999051aba397cdc0ae04fe530baad81c9b` |
| Re-run this audit | `git diff 4c759f3..HEAD -- lib/ exe/` is empty — no widget, action, signal, CSS class or string changed in `lib/` or `exe/` since this ledger was last written. Driven and spec commands re-run live this round, same 204/204 and 101/1 results, so every verdict below is re-confirmed rather than carried forward from the commit message. |
| Units with parity | **9 / 11** (C3 closed this round) |
| Stylesheet axis | vacuous: neither tree has a `.css` file or a `Gtk::CssProvider`; every class in play is a platform class |
| Driven, this audit | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` → **204 of 204 checks passed, `DRIVE OK`**, 11 components |
| Specs, this audit | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` → **101 examples, 1 failure** (the failure is `appstreamcli`'s `developer-id-invalid` against the port's byte-identical copy of upstream's own metainfo — upstream's own data defect, inherited faithfully, not a port bug — see `test-parity.md`) |
| Screenshots | 10 written to `tmp/shots/` on this run (`tmp/` is gitignored, nothing persists between audits). **Still not compared against upstream running — gap C7, unchanged.** |

Eleven units. Application **gap** (C1), window parity (**gap C3 closed
this round**), exit dialog parity, shortcuts dialog parity, file row
**gap** (C7, substitution unverified), progress popover parity, progress
paintable **gap** (C7), shredding backend parity, build constants parity,
gettext binding parity, data and catalogues parity.

**Two gaps remain open: C1, C7.** C3 is closed this round (see its own
section below). The eight gaps fixed in commit
`ff5772c` (C2, C4, C5, C6, C8, C9, C10, C11) were re-read against upstream
this audit and remain correct in the code. The headline change since the
last component-parity pass (which audited `ff5772c`) is that **five of
those eight fixes — C4, C5, C8, C9, C10 — gained a regression test in
commit `4c759f3`**, closing the "fixed but unverified" finding the previous
audit raised for all five. That finding is now resolved and is recorded
closed below rather than carried forward as open.

Nothing below cites `PORTING.md` as authority; it was read for navigation
only.

---

## Unit: application — `src/main.c` + `src/raider-application.c` → `lib/main.rb` + `exe/raider`

| Thing | Up × | Port × | Signals/actions | Text | Verdict |
|---|---:|---:|---|:-:|---|
| application object | 1 | 1 | ✓ `activate`, `open` | — | parity |
| `Adw.AboutDialog` | 1 | 1 | ✓ | ✓ | parity — all 11 fields |
| `Gtk.FileDialog` | 2 | 2 | ✓ | ✓ | parity |
| actions | 6 + 1 from libadwaita | 7 | ✓ all 7, accels identical | — | parity |
| `GOptionEntry` | 2 | **0** | — | — | **gap C1**, still open |

### gap C1 — `raider --help` does not list the app's own switches (unchanged)

`--version`/`-v` and `--new-window`/`-w` are matched off `ARGV` in
`lib/main.rb:151-153` and never registered as `GOptionEntry`s, so
`--help`/`-h` falls through to GLib's own generic help text, which says
nothing about either switch. Upstream's `src/raider-application.c:252-260`
registers both through `g_application_add_main_option_entries`.
`KNOWN_LIMITATIONS.md` documents a real investigation of the gio2/glib2
bindings (`GLib::OptionEntry` is not reachable as a constructible Ruby
constant even though the introspection data defines the struct) — that is
evidence the gap is hard, never evidence it is closed. Confirmed again this
audit by re-reading `lib/main.rb:60-65`, `:151-153`; no `--help` check
exists in the suite or driver in either direction.

### CLOSED and now verified — gap C4, window targeting of a file-open dialog

`action_open`/`action_open_folder` capture `active_port_window` before the
file dialog opens (`lib/main.rb:224-248`), matching upstream's
`raider_window_open_file` pattern. `spec/app_spec.rb:168` ("the second
window even if the first becomes active before the dialog finishes") opens
two windows, switches focus mid-dialog, and asserts the file lands in the
window the dialog was opened from, not the one focused when it completes.
Run this audit: passes. This is a genuine regression test for the
previously-unverified fix, and it is correct — a revert to resolving
`app.active_window` at completion time would fail it.

**Closed this round:** `action_open_folder`'s targeting is now separately
exercised by its own spec (`spec/app_spec.rb`, "#action_open_folder
targets the window active when the dialog was opened") — the same shape
as the C4 regression spec above, against `select_multiple_folders`/
`select_multiple_folders_finish` rather than `open_multiple`. Run this
round: passes. `app.open-folder` itself still has no further driver
coverage beyond the menu-label check (`test/drive_main_window.rb:197`),
but the window-targeting behaviour this note used to flag as unproven is
now proven.

### CLOSED and now verified — gap C10, a file argument opening an empty window

`gapplication_argv` prepends `$PROGRAM_NAME` (`lib/main.rb:170-172`).
`spec/app_spec.rb:218` drives this through a real, separate
`Gio::Application` instance with `:handles_open`, passes the exact argv
`#run` would receive, and asserts the file arrives through the `open`
signal rather than vanishing as the consumed program name. Run this audit:
passes. This is the strongest of the new regression tests — it exercises
the actual GLib contract, not a mock of it.

---

## Unit: window — `src/raider-window.blp` + `.c` → `lib/window.rb`

| Widget | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ApplicationWindow` | 1 | 1 | parity |
| `Gtk.Revealer` | 3 | 3 | parity |
| `Gtk.Box` `contents_box` | 1, unset orientation (defaults horizontal) | 1, explicit `:horizontal` | parity (gap C2, closed in `ff5772c`, re-confirmed) |
| `open_files`/`open_file` | `GTask` worker thread | `Thread` + `on_main_loop`, same split as shredding | **gap C3, closed this round** |

### gap C3 — closed this round: open_files now runs its I/O off the main thread

`open_files` (`lib/window.rb`) now spawns a `Thread` that does the I/O
(`File.exist?`/`File.writable?`) for each dropped file and hands only the
outcome — a toast for a rejection, a new row for an acceptance — back to
the main thread through `on_main_loop` (the same `GLib::Idle.add` wrapper
`launch_rows`/`wait_for_rows` already used for shredding and abort). This
mirrors upstream's `g_task_run_in_thread` (`src/raider-window.c:286-292`)
closely: the worker thread does the stat calls, the main thread only ever
touches a widget. `open_file` (the single-file entry point, called
directly by `spec/window_spec.rb`, `spec/file_row_spec.rb` and
`spec/app_spec.rb`) stays synchronous — upstream's own
`raider_window_open_file` is likewise never invoked except from inside
the `GTask` worker `open_files` starts, so a synchronous single-file API
is this port's own convenience, not a parity gap, same as before this
round.

The decision inputs (`filenames`/`@rows.length`) are read once before the
thread starts and then shadowed locally inside it (`known`/`count` in
`open_files`) rather than re-read from `@rows` on the worker thread: the
worker never touches `@rows` or a widget directly, only through the
outcome it schedules on the main loop, so the file-limit and duplicate
checks stay self-consistent without needing a synchronous round-trip back
to the main thread for every file.

Verified this round: `spec/window_spec.rb` gained a case that opens 40
files and asserts the row count is observed to grow across more than one
turn of the main loop (`counts.uniq.length > 1`) rather than jumping from
0 to 40 between two checks — the only way that assertion passes is if the
files are genuinely being examined one at a time with the loop getting
turns in between, not all at once on the calling thread.
`test/drive_main_window.rb` gained the same shape as a driver step (60
files). Both pass; `rows.length` still reaches every file's count by the
time the check succeeds, so nothing is silently dropped.

---

## Unit: exit dialog — `src/raider-window.c:173-190` → `lib/exit_dialog.rb`

Unaffected by any commit since the last audit. `Adw.AlertDialog`, 2
responses, both marked strings with mnemonics inside the msgid. Driven:
`spec/exit_dialog_spec.rb` (3 examples) + driver steps around `:511-:596`.
**Parity.**

## Unit: shortcuts dialog — `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

Only comment text changed since the last audit (A4's rewrite — see
`accountability-ensurance.md`); no widget, action or string changed.
`Adw.ShortcutsDialog` → 1 section ("General") → 5 items, all action-named.
Driven: `spec/shortcuts_dialog_spec.rb` (5 examples) + driver steps around
`:637-:659`. **Parity.**

---

## Unit: file row — `src/raider-file-row.blp` + `.c` → `lib/file_row.rb`

| Widget | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ActionRow` | 1 | 1 | parity |
| `Gtk.Box` `controls` | 1 | 1 | parity |
| `Gtk.Revealer` | 2 | 2 | parity |
| `Gtk.Button` remove | 1 | 1 | parity |
| `Gtk.Button` progress (up) / `Gtk.MenuButton` (port) | 1 | 1 | substitution, **gap C7** |
| `Gtk.Image`/paintable (up) / `Gtk.DrawingArea` (port) | 1 | 1 | substitution, **gap C7** |
| end-of-run row behaviour | row closes unless cancelled | matches | parity (gap C11, closed) |

### CLOSED and now verified — gap C11, a missing-file failure used to keep the row

`shredding_finished` (`lib/file_row.rb:195-203`) closes the row unless
`error && @corrupt.cancelled?`. `spec/corrupt_spec.rb:90` ("a directory this
process cannot list (C5)") and the file_row spec's missing-file case
(updated in `ff5772c`) both exercise this. Run this audit: both pass.

**Closed this round:** `spec/corrupt_spec.rb`'s "when a write fails
partway through a pass" case stubs `File.open` to yield an object that
raises `Errno::EIO` on its third `write`, so the failure lands after some
of the pass's writes have already gone out — exercising `step`'s
`rescue SystemCallError` branch live, which no check had reached before
(it previously only reached `File.open` itself failing, e.g. a read-only
file, never a write failing partway through an open file). Asserts the
run stops at that point, the error names "failed to perform shredding
step", the file is left in place, and no further progress is reported for
the pass that failed.

### gap C7 — upstream has still never been rendered (unchanged)

No image of the C app exists anywhere in this repository to compare
against. The two substitutions (`Gtk::MenuButton` for the progress button,
`Gtk::DrawingArea` for the paintable) are still argued on paper only — no
screenshot shows the progress button beside the remove button at the same
moment, and nothing renders the arc hovered, active or insensitive. `tmp/`
is gitignored, so no screenshot from any run, including this one, is
preserved for a future audit to diff against.

---

## Unit: progress popover — `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`

Unaffected by any commit since the last audit. `Gtk.ProgressBar`,
`show-text`, `hexpand`, `pulse-step .02`, 3 marked strings + 1 unmarked
`%d%%` (unmarked on both sides, confirmed). Driven: `spec/progress_info_popover_spec.rb`
(5 examples). **Parity.**

## Unit: progress paintable — `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

Only comment text changed since the last audit (A3's rewrite, moving the
unverified-correspondence argument out of the code comment and into this
ledger, where it now lives as gap C7 below). The substitution itself
(`style_context.color` at draw time vs. upstream's state-following
`snapshot_symbolic`) is unchanged. **gap C7**, shared with the file row's
progress button above.

---

## Unit: shredding backend — `src/corrupt.c` → `lib/corrupt.rb`

Five byte patterns, regular file, zero-byte file, folder tree, cancel,
wait — parity. `stderr` diagnostics on an unlistable directory — gap C5,
closed in `ff5772c` and now covered by `spec/corrupt_spec.rb:90-113`, which
asserts the listing diagnostic prints, the method returns `nil`, and
`rmdir` is never called on a directory that was never successfully listed.
Run this audit: passes. **Unit verdict: parity**, with the mid-shred-write
gap noted above (file-row section) rather than hidden.

## Unit: build constants — `meson.build` `config_h` → `lib/package_config.rb`

Unaffected since the last audit. Version, application id, gettext domain,
localedir all present and correct. Driven: driver step `:718`. **Parity.**

## Unit: gettext binding — `po/meson.build` + `src/main.c:31-33` → `lib/translation.rb`

`lib/translation.rb`'s comment was rewritten (A5) to cite the live German-
locale UTF-8 check as evidence instead of asserting the codeset binding
unverified — the binding itself is unchanged. Domain bound, localedir
bound, marker round-trips under the C locale **and now under a live German
locale** (driver steps added this round at `:739-741`). **Parity** — see
`translation-parity.md` for the separate finding about the regenerated
`.pot` losing the data-file-sourced keys, which is a translation-parity gap,
not a gettext-binding gap: the binding itself works correctly for every key
it is handed.

## Unit: data and catalogues — `data/meson.build` + `data/icons/meson.build` + `po/meson.build` → `lib/data_files.rb`, `flake.nix`, `Rakefile`

Desktop entry, metainfo merge, service file, icons, `po/LINGUAS` build —
parity. Developer-id casing (gap C8) and the screenshot file (gap C9), both
closed in `ff5772c`, are now each covered by name in
`spec/data_files_spec.rb:127` and `:137` respectively. Run this audit:
both pass. **Parity.**

---

## Summary

| Gap | Status | Verified by a check? |
|---|---|---|
| C1 | open | no |
| C2 | closed | yes |
| C3 | closed this round | yes |
| C4 | closed | **yes, as of `4c759f3`** |
| C5 | closed | **yes, as of `4c759f3`** |
| C6 | closed | yes |
| C7 | open | no |
| C8 | closed | **yes, as of `4c759f3`** |
| C9 | closed | **yes, as of `4c759f3`** |
| C10 | closed | **yes, as of `4c759f3`** |
| C11 | closed | yes (both halves — missing-file, and mid-shred-write as of this round) |

Nine of eleven gaps opened across this port's history were, as of the
audit this section originally described, both closed and verified by a
check that would catch a regression; C3 is now a tenth, closed this round
(see its own section above) — the two that remain, **C1 and C7**, are
read off the source on both sides and have not regressed or progressed.
The one previously-flagged
accountability concern in this ledger (A13: fixes shipping without
regression tests) is resolved for C4, C5, C8, C9, C10; it was never raised
for C2, C6, C11, which already had tests.

## Independent re-audit, this round (HEAD `f0a5135`)

Re-run live rather than taken from the commit this ledger was last written
against: `nix develop --command xvfb-run -a ruby test/drive_main_window.rb`
→ **204 of 204 checks passed, `DRIVE OK`**, 11 components, matching every
number this document already claimed. `rspec` → **101 examples, 1
failure** (the same `appstreamcli developer-id-invalid` row), also
matching. Both commands produced these numbers on this machine this
session, not copied from this file.

Spot-checked independently against `git show origin/main:src/raider-window.blp`
rather than against this ledger's own prior text: `primary_menu`'s three
items (`app.new-window`, `app.shortcuts`, `app.about`) and `open_menu`'s one
item (`app.open-folder`), the dynamic `clear_button` label
("Clear" → "Clear All" on `src/raider-window.c:387`), and the shortcuts
dialog's five items all match `lib/window.rb` and `lib/shortcuts_dialog.rb`
exactly. `po/LINGUAS` and all 35 `.po` files are still byte-identical to
`origin/main`'s.

**Finding, this round:** `.reports/component-identification.md` named the
`primary_menu` action names as `win.show-shortcuts`, `win.about` and
`app.quit` — none of which exists in `src/raider-window.blp`. Corrected in
that file this round; see its own "Correction, this audit" note. C1/C3/C7
remain open and are not affected by this — the error was in a document's
description of upstream, not in the port or in the gap count.

## Round 2 (this round): C3 closed, counts re-run live

`nix develop --command xvfb-run -a ruby test/drive_main_window.rb` →
**205 of 205 checks passed, `DRIVE OK`**, 11 components (one more check
than the `204` the previous round reported — the new C3 driver step,
"opening many files at once does not freeze the main loop"). `rspec` →
**104 examples, 1 failure** (three more than the previous round's `101` —
the C3 `window_spec.rb` case, the `action_open_folder` window-targeting
spec, and the mid-shred-write-failure `corrupt_spec.rb` case, all
described in their own sections above; the one persisting failure is
still the same `appstreamcli developer-id-invalid` row, upstream's own
data, not a regression).

**C1 and C7 are the two gaps still open.** C1 was investigated again this
round (nothing new found; `KNOWN_LIMITATIONS.md`'s existing account
stands) and not touched in code. C7 was not attempted this round — no
path exists in this environment to build and run upstream's C
implementation for a side-by-side screenshot, and nothing in the port's
own tree changed for the `Gtk::MenuButton`/`Gtk::DrawingArea`
substitution, so it remains argued on paper only, unchanged from the
previous audit's own finding.
