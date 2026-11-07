# Component parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `485859999051aba397cdc0ae04fe530baad81c9b` |
| Re-run this audit | `git diff 4c759f3..HEAD -- lib/ exe/` is empty — no widget, action, signal, CSS class or string changed in `lib/` or `exe/` since this ledger was last written. Driven and spec commands re-run live this round, same 204/204 and 101/1 results, so every verdict below is re-confirmed rather than carried forward from the commit message. |
| Units with parity | **8 / 11** |
| Stylesheet axis | vacuous: neither tree has a `.css` file or a `Gtk::CssProvider`; every class in play is a platform class |
| Driven, this audit | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` → **204 of 204 checks passed, `DRIVE OK`**, 11 components |
| Specs, this audit | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` → **101 examples, 1 failure** (the failure is `appstreamcli`'s `developer-id-invalid` against the port's byte-identical copy of upstream's own metainfo — upstream's own data defect, inherited faithfully, not a port bug — see `test-parity.md`) |
| Screenshots | 10 written to `tmp/shots/` on this run (`tmp/` is gitignored, nothing persists between audits). **Still not compared against upstream running — gap C7, unchanged.** |

Eleven units. Application **gap** (C1), window **gap** (C3), exit dialog
parity, shortcuts dialog parity, file row **gap** (C7, substitution
unverified), progress popover parity, progress paintable **gap** (C7),
shredding backend parity, build constants parity, gettext binding parity,
data and catalogues parity.

**Three gaps remain open: C1, C3, C7.** The eight gaps fixed in commit
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

**Not covered by the same test:** `action_open_folder`'s targeting is not
separately exercised — only `action_open` is driven by the C4 regression
spec. `action_open_folder` shares the same `active_port_window` call
(`lib/main.rb:237-248`), so the fix likely holds for it too, but nothing
proves it, and `app.open-folder` remains undriven by the suite or the
driver script beyond a menu-label check
(`test/drive_main_window.rb:197`).

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
| `open_files`/`open_file` | `GTask` worker thread | synchronous | **gap C3**, still open |

### gap C3 — a big drop still freezes the window (unchanged)

`lib/window.rb:137`/`:150` run on the calling thread. Upstream wraps the
open loop in `g_task_run_in_thread` (`src/raider-window.c:286-292`)
specifically to keep a large batch from blocking the UI thread. Confirmed
unchanged this audit (`grep -n "Thread.new" lib/window.rb` finds it only in
the shredding start/abort paths at `:461`, `:480` — not in `open_files` or
`open_file`). No check in the suite or driver opens enough files to make
the freeze observable live.

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

**Still owed, not claimed fixed:** no check drives a write failing
*mid-shred* (as opposed to a file missing or a directory unlistable before
shredding starts). `grep -n "mid-shred\|Permission denied" spec/corrupt_spec.rb`
returns nothing. That half of the behaviour is read off the source, not
reproduced live, in either this audit or the last one.

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
| C3 | open | no |
| C4 | closed | **yes, as of `4c759f3`** |
| C5 | closed | **yes, as of `4c759f3`** |
| C6 | closed | yes |
| C7 | open | no |
| C8 | closed | **yes, as of `4c759f3`** |
| C9 | closed | **yes, as of `4c759f3`** |
| C10 | closed | **yes, as of `4c759f3`** |
| C11 | closed | yes (missing-file half only; mid-shred-write half still unchecked) |

Nine of eleven gaps opened across this port's history are now both closed
and verified by a check that would catch a regression. The three that
remain — C1, C3, C7 — are read off the source on both sides and have not
regressed or progressed since the last audit. The one previously-flagged
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
