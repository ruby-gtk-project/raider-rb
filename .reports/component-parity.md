# Component parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `ff5772c81f84cbfd2f2a126483e9bf811d0b0896` |
| Units with parity | **8 / 11** |
| Stylesheet axis | vacuous: neither tree has a `.css` file or a `Gtk::CssProvider`; every class in play is a platform class |
| Driven (Step 5) | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb`, re-run this audit — **202 of 202 checks passed, 40 steps, 11 components** |
| Specs | re-run this audit — `96 examples, 0 failures, 2 pending`. The 2 pending are the only two tests upstream has — see `test-parity.md` |
| Screenshots (Step 4, second half) | 17 written to `tmp/shots/` on this audit's drive run. **Still not compared against upstream running** — see gap C7 |

Eleven units. Parity: application **gap**, window **gap**, exit dialog
parity, shortcuts dialog parity, file row parity, progress popover parity,
progress paintable **gap**, shredding backend parity, build constants
parity, gettext binding parity, data and catalogues parity.

**Three gaps remain open: C1, C3, C7.** Eight that were open at the last
audit (C2, C4, C5, C6, C8, C9, C10, C11) were fixed in commit `ff5772c`,
re-read in this audit and confirmed closed in the code. **Two of those eight
— C4 and C10 — are fixed with zero test coverage of the fix**, which this
audit treats as its own finding below rather than as a closed row with
nothing left to say about it. C2 took three audits to close.

Nothing below cites a port document as authority. `PORTING.md` was read for
navigation only, and it is itself a finding — `PORTING.md` still states
"5/9 units, 16 open gaps" and "93 passed, 0 pending", both wrong before this
audit and wrong again now that C2/C4/C5/C6/C8-C11 are closed and nobody
updated it. See `accountability-ensurance.md`, item A7.

---

## Unit: application — `src/main.c` + `src/raider-application.c` → `lib/main.rb` + `exe/raider`

| Thing | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application object | 1 | 1 | — | ✓ `activate`, `open` | — | parity — `Adw.Application` → `Gtk::Application` + explicit `Adwaita.init` (`lib/main.rb:90-94`) |
| `Adw.AboutDialog` | 1 | 1 | — | ✓ | ✓ | parity — all 11 fields, `translator-credits` at `lib/main.rb:130` |
| `Gtk.FileDialog` | 2 | 2 | — | ✓ | ✓ `Add Files`, `Add Folders` | **FIXED, unverified** — see below |
| actions | 6 installed (+1 from libadwaita) | 7 installed | — | ✓ all 7, accels identical | — | parity |
| `GOptionEntry` | 2 | **0** | — | — | — | **gap C1**, still open |
| file arguments (`HANDLES_OPEN`) | every argument opens | now every argument opens | — | — | — | **FIXED, unverified** — see below |

Driven: `test/drive_main_window.rb` steps at `:170` (all seven actions and
their accelerators), `:204` (`app.new-window`), `:214` (`app.close`),
`:542` (`app.quit` refused while shredding), `:612` (About dialog on
screen), `:637` (shortcuts dialog), `:771` (`--version`).
**Still not driven:** `app.open`, `app.open-folder` and the `open` signal.
Confirmed again this audit — `grep -n "\"app\.open\|action_open\b"
spec/*.rb test/*.rb` returns nothing but the two action-name assertions in
`spec/app_spec.rb:27-28`. The two file dialogs are checked only for
existence.

### gap C1 — `raider --help` does not list the app's own switches (unchanged)

`--version`/`-v` and `--new-window`/`-w` are matched off `ARGV` in
`lib/main.rb:151-153` and never registered as `GOptionEntry`s anywhere, so
`--help`/`-h` still falls through to `application_arguments`
(`lib/main.rb:160-164`), reaches GLib as an unknown long option, and GLib's
own `--help` text — which this process never customised — says nothing
about either switch. Upstream's `src/raider-application.c:252-260` registers
both through `g_application_add_main_option_entries`, so upstream's
`--help` lists them. Confirmed by reading; not re-exercised live this audit
because nothing in the suite or driver asserts on `--help` output either
way — that absence is itself worth noting, since it means this gap could
regress silently in either direction.

### FIXED, unverified — files from a dialog landing in the wrong window (was gap C4)

`action_open` and `action_open_folder` now call `active_port_window` and
capture `target` **before** `Gtk::FileDialog#open_multiple` is invoked
(`lib/main.rb:224-248`), matching upstream's `raider_window_open_file`
pattern of resolving the window once, at dialog-presentation time
(`src/raider-application.c:79-84`). Read against upstream, the fix is
correct.

No check proves it. `active_port_window` (`lib/main.rb:288-291`) has no
spec and no driver step. A regression that reverted to
`app.active_window` at completion time — exactly the bug this fix removed —
would pass all 202 driven checks and all 96 specs today, because none of
them opens two windows and then drives either file dialog. This is the gap
the task's framing calls out directly: a component no check exercises is
unverified, not done, and this one has now been "fixed" twice without ever
being driven once.

### FIXED, unverified — `raider myfile.txt` opening an empty window (was gap C10)

`gapplication_argv` now prepends `$PROGRAM_NAME` (`lib/main.rb:170-172`) so
`Gtk::Application#run` no longer reads the first real filename as its own
program name and drops it — matching `g_application_run`'s documented
contract that `argv[0]` is the program name. Read against upstream, the fix
is correct.

No check proves it. `spec/app_spec.rb:148`, `:154` assert which strings
`application_arguments` returns and stop one method short of `#run`;
`test/drive_main_window.rb` never launches the app with a file argument on
its simulated command line. The bug this fix removed — the first file
argument silently vanishing — would reproduce today exactly as it did
before `ff5772c`, and nothing would notice.

---

## Unit: window — `src/raider-window.blp` + `src/raider-window.c` → `lib/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✓ | parity — 800×600, 270×300 minimum, icon |
| `Gtk.Revealer` | 3 | 3 (1 + repeater ×2) | — | — | — | parity — `floating_revealer` (`lib/window.rb:418-426`) |
| `Gtk.Box` `contents_box` | 3 | 3 (1 + repeater ×2) | — | — | — | **FIXED** — now `Gtk::Box.new(:horizontal, 0)` (`lib/window.rb:344`), matching the blueprint's unset (default-horizontal) orientation |
| `open_files` | GTask worker | synchronous | — | — | — | **gap C3**, still open |

### gap C2 — the content box ran the wrong way — CLOSED this audit

`lib/window.rb:341-344` now reads *"Upstream's `Gtk.Box contents_box` sets
no `orientation`, so it defaults to [horizontal]"* and constructs
`Gtk::Box.new(:horizontal, 0)`. Confirmed against
`src/raider-window.blp:50`, which sets no `orientation` property, and GTK's
own default for `Gtk.Box` is `:horizontal`. Driven: step `:239` in
`test/drive_main_window.rb` lays out three rows and reads their positions,
which would fail under the old vertical box — this is the one C-gap in this
audit that a check would actually have caught had it regressed, because the
positions it reads are orientation-sensitive.

### gap C3 — a big drop still freezes the window (unchanged)

`lib/window.rb:135-145`'s `open_files`/`open_file` run on the calling
thread; upstream wraps the open loop in `g_task_run_in_thread`
(`src/raider-window.c:286-292`) specifically so a large batch of files does
not block the UI thread. Nothing in `ff5772c` touched this path. No check
in the suite or driver opens enough files to make the freeze observable, so
the gap is read off the source on both sides, not reproduced live.

---

## Unit: exit dialog — `src/raider-window.c:173-190` → `lib/exit_dialog.rb`

Unaffected by this round's fix commit. Re-read against upstream this audit;
no change in verdict.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AlertDialog` | 1 | 1 | — | ✓ `response` | ✓ `Stop Shredding?`, `Are you sure that you want to exit?` | parity |
| responses | 2 | 2 | ✓ `exit` destructive | ✓ | ✓ `_Cancel`, `_Exit` (mnemonics inside the msgid) | parity |

`default-response` and `close-response` are both `cancel` on both sides.
Driven: `spec/exit_dialog_spec.rb` 3 examples, plus driver steps `:511`,
`:517`, `:535`, `:585`, `:596`. Screenshot: `tmp/shots/14-exit-dialog.png`.
**Parity.**

---

## Unit: shortcuts dialog — `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

Unaffected by this round's fix commit. Re-read against upstream this audit;
no change in verdict.

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | — | ✓ (no title on either side) | parity |
| `Adw.ShortcutsSection` | 1 | 1 | — | — | ✓ `General` | parity |
| `Adw.ShortcutsItem` | 5 | 5 | — | ✓ 5 action names | ✓ 5 titles | parity |

Driven: `spec/shortcuts_dialog_spec.rb` 5 examples, plus driver steps `:637`
and `:659`. Screenshot: `tmp/shots/17-shortcuts-dialog.png`. **Parity.**

---

## Unit: file row — `src/raider-file-row.blp` + `src/raider-file-row.c` → `lib/file_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` `controls` | 1 | 1 | — | — | — | parity, `valign: center`, matches upstream |
| `Gtk.Revealer` | 2 | 2 | — | — | — | parity, both `slide_left`, both initial states |
| `Gtk.Button` `remove_button` | 1 | 1 | ✓ none, as upstream | ✓ `clicked` | — | **FIXED** — `valign` removed (`lib/file_row.rb:126-133`) |
| `Gtk.Button` `progress_button` | 1 | 0 | — | ✓ popover popup | — | substitution → `Gtk::MenuButton`, `always_show_arrow` now documented as a consequence of the substitution rather than left bare — **gap C7 still covers the substitution itself** |
| `Gtk.Image` from paintable | 1 | 0 | — | — | — | substitution → `Gtk::DrawingArea` — **gap C7** |
| end-of-run behaviour | row removed on any non-cancellation outcome | now matches | — | — | — | **FIXED** |

Messages: 0 upstream, 0 in the port. Correct.
Driven: `spec/file_row_spec.rb` 12 examples (updated in `ff5772c` to assert
the corrected `shredding_finished` behaviour), plus driver steps `:239`,
`:315`, `:412`, `:457`.

### gap C6 — two invented properties — CLOSED this audit

`remove_button` (`lib/file_row.rb:126-133`) and `progress_button`
(`lib/file_row.rb:141-151`) no longer set `valign`; `controls` already
centres both (confirmed against `src/raider-file-row.blp:10-24`, which sets
`valign: center` on the box and nothing on either button). The comments
above both methods now say this explicitly and cite the reason
`always_show_arrow` still differs (the `Gtk::MenuButton` substitution draws
its own disclosure arrow by default; upstream's plain button draws none).
Correct and complete.

### gap C11 — a file the app failed to shred used to stay in the list — CLOSED this audit

`shredding_finished` (`lib/file_row.rb:195-203`) now closes the row unless
`error && @corrupt.cancelled?`, matching upstream's `g_task_had_error`,
which `src/corrupt.c:192` sets in exactly one place
(`g_task_return_error_if_cancelled`) — a failed `fopen` or a missing file
never touches the task, so upstream's row closes on both kinds of failure
and only a cancellation leaves it. The comment that used to misstate this
(quoted and refuted in the previous audit) has been replaced with an
accurate one. `spec/file_row_spec.rb` was updated in the same commit to
assert the corrected behaviour — this is the one fix in this round that
*does* carry its own test, unlike C4 and C10 above.

Still owed, and not claimed fixed: no check drives a write failing
*mid-shred* (as opposed to a file missing before shredding starts), so the
"failed write" half of this fix is read off the source, not reproduced
live. The "missing file" half is driven (`test/drive_main_window.rb`'s
fatal-row step, and `spec/corrupt_spec.rb`'s missing-file case).

### gap C7 — the port has now been looked at; upstream has not (unchanged)

Carried forward verbatim from the last audit — nothing in `ff5772c` touched
screenshot rendering, upstream still was not built or rendered, and the two
visible substitutions (`Gtk::MenuButton` for the progress button,
`Gtk::DrawingArea` for the paintable) are still argued on paper only:

* **Upstream was never rendered.** No image of the C app exists in this
  repository to compare against.
* **`Gtk.Button` → `Gtk::MenuButton`.** No screenshot shows the progress
  button beside the remove button at the same moment, so whether the two
  trailing buttons are the same size is still unmeasured.
* **`GtkSymbolicPaintable` → `Gtk::DrawingArea`.** Nothing renders the arc
  hovered, active or insensitive — the one state-following behaviour the
  substitution could get wrong is the one thing untested.
* **`tmp/shots/09-shredding.png`** — not re-verified this audit whether it
  is still empty; `tmp/` is gitignored, so no image from any run is
  preserved for this audit or any future one to diff against.

---

## Unit: progress popover — `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`

Unaffected by this round's fix commit. Re-read against upstream this audit;
no change in verdict. `Gtk.ProgressBar`, `show-text`, `hexpand`,
`pulse-step .02`, 3 marked strings + 1 unmarked `%`. Driven:
`spec/progress_info_popover_spec.rb` 5 examples. **Parity.**

---

## Unit: progress paintable — `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

Unaffected by this round's fix commit. The symbolic-colour substitution
(`style_context.color` at draw time vs. upstream's state-following
`snapshot_symbolic`) is the same substitution gap C7 names for the file
row's progress button — one architectural divergence, flagged against two
units because it is visible in both. **gap C7.**

---

## Unit: shredding backend — `src/corrupt.c` → `lib/corrupt.rb`

| Thing | Verdict |
|---|---|
| five byte patterns, regular file, zero-byte file, folder tree, cancel, wait | parity |
| `stderr` diagnostics | **FIXED this audit** |

### gap C5 — one diagnostic was swallowed, the wrong one printed — CLOSED this audit

`openable_entries` (`lib/corrupt.rb:230-237`) now rescues `SystemCallError`
on the directory listing itself, prints upstream's own diagnostic
(`"corrupt: failed to open directory for removal"`, matching
`src/corrupt.c:219-224`'s `fprintf`) and returns `nil` so `#remove_directory`
is skipped — a directory that cannot be opened is no longer reported as a
directory that could not be *removed*. Correct, read against upstream.
Driven: `spec/corrupt_spec.rb` folder-tree case continues to pass; no new
example specifically drives the "cannot open for listing" branch (as
opposed to "cannot remove"), so this fix, like C4 and C10 in the
application unit, is correct on inspection but not exercised by a check
that would catch a regression.

Unit verdict: **parity**, with the one caveat above noted rather than
hidden.

---

## Unit: build constants — `meson.build` `config_h` block → `lib/package_config.rb`

Unaffected by this round's fix commit. Version, application id, gettext
domain, localedir all present and correct. Driven: driver step `:718`.
**Parity.**

---

## Unit: gettext binding — `po/meson.build` + `src/main.c:31-33` → `lib/translation.rb`

Unaffected by this round's fix commit. Domain bound, localedir bound,
marker string round-trips under the C locale. Driven: driver step `:728`.
**Parity** in what is checked — see `accountability-ensurance.md` item A5
and `translation-parity.md` gap T3 for what the C-locale-only check cannot
see (the codeset binding, and any non-English locale).

---

## Unit: data and catalogues — `data/meson.build`, `data/icons/meson.build`, `po/meson.build` → `lib/data_files.rb`, `flake.nix`, `Rakefile`

| Thing | Verdict |
|---|---|
| desktop entry, metainfo merge, service file, icons, `po/LINGUAS` build | parity |
| AppStream `developer id` casing | **FIXED this audit** |
| `data/raider-screenshot1.png` | **FIXED this audit** |

### gap C8 — the developer id was retyped — CLOSED this audit

`data/com.github.ADBeveridge.Raider.metainfo.xml.in.in:24` now reads
`<developer id="io.github.ADBeveridge">`, byte-identical to upstream's
casing. Confirmed by diff against `git show
origin/main:data/com.github.ADBeveridge.Raider.metainfo.xml.in.in`.

### gap C9 — the screenshot was gone — CLOSED this audit

`data/raider-screenshot1.png` exists (33012 bytes) and the metainfo's
`<image>` element at `:51` still points at it by the same relative path
upstream uses. Not byte-diffed against upstream's copy of the same file
this audit — only presence and the reference were checked — so note that
as the one thing left unverified about this specific fix, though a wrong
image would be a cosmetic gap, not a functional one.

Unit verdict: **parity**. Driven: driver step `:755` (AppStream carries
`xml:lang`) and step `:745` (all three installable files written and
non-empty); neither step was written to check developer-id casing or the
screenshot file's presence specifically, so — as with C4, C10 and C5 above
— these two fixes are correct on inspection, not exercised by name in any
check.

---

## Summary of what this audit closes and what it leaves open

| Gap | Status | Verified by a check? |
|---|---|---|
| C1 | open | no |
| C2 | **closed** | yes — step `:239` is orientation-sensitive |
| C3 | open | no |
| C4 | **closed in code** | **no — unverified** |
| C5 | **closed in code** | no (branch not specifically driven) |
| C6 | **closed** | yes — `spec/file_row_spec.rb` property assertions |
| C7 | open | no |
| C8 | **closed in code** | no (casing not asserted by name) |
| C9 | **closed in code** | no (file identity not asserted) |
| C10 | **closed in code** | **no — unverified** |
| C11 | **closed** | yes — `spec/file_row_spec.rb` updated in the same commit |

Six of the eight code fixes in `ff5772c` shipped without a check that would
catch a regression of the specific bug fixed. Two (C6, C11) did add or
update an assertion. This table is this audit's single most important
output: "fixed" and "fixed and verified" are not the same claim, and the
component-parity ledger from the previous audit did not distinguish them.
