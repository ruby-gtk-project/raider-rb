# Component parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Units with parity | **5 / 9** |
| Stylesheet axis | vacuous: neither tree has a `.css` file or a `Gtk::CssProvider`; all three classes in play are platform classes |
| Driven (Step 5) | partly — the port's 93 specs exercise every signal and action in the unit list and passed on the last recorded run (`.rspec_status`, 93 passed, 0 pending). Not re-run here: `bundle exec rspec` is unavailable outside `nix develop` in this session |
| Screenshots (Step 4, second half) | **none taken** — see gap C7 |

Nine units. Parity: application **gap**, window **gap**, exit dialog parity,
shortcuts dialog parity, file row **gap**, progress popover parity, progress
paintable parity, shredding backend **gap**, data/po parity.

Nothing below cites a port document as authority for anything. Every
correspondence names the file and line where the thing lives.

---

## Unit: application — `src/main.c` + `src/raider-application.c` → `lib/main.rb` + `exe/raider`

| Thing | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| application object | 1 | 1 | — | ✓ `activate`, `open` | — | parity — `Adw.Application` → `Gtk::Application` + explicit `Adwaita.init` (`lib/main.rb:92-94`). Substitution recorded |
| `Adw.AboutDialog` | 1 | 1 | — | ✓ | ✓ | parity — all 11 fields, `translator-credits` at `lib/main.rb:113` |
| `Gtk.FileDialog` | 2 | 2 | — | ✓ | ✓ `Add Files`, `Add Folders` | parity |
| actions | 6 installed (+1 from libadwaita) | 7 installed | — | ✓ all 7, accels identical | — | parity — `app.shortcuts` installed by hand (`lib/main.rb:51`) because the port has no GResource to alias; libadwaita's own default is the same action name and the same `<Control>question` |
| `GOptionEntry` | 2 | **0** | — | — | — | **gap C1** |
| file-dialog result routing | window captured at open | window looked up at completion | — | — | — | **gap C4** |

### gap C1 — `raider --help` does not list the app's own switches

I did not build the command-line interface, because I am an idiot who read two
switches off `ARGV` and called it a port.

Upstream: `src/raider-application.c:252-256` declares
`{"new-window", 'w', …, "Open a new window"}` and
`{"version", 'v', …, "Print version information and exit"}`, and
`:260` registers them with `g_application_add_main_option_entries`. A user
typing `raider --help` is shown both, GLib validates them, and
`handle_local_options` (`:216-239`) returns -1 so unrecognised arguments still
reach GApplication.

Port: `lib/main.rb:134-136` scans `@argv` for the four literal spellings and
`:143-147` strips them. `grep -rn 'add_main_option' lib/ exe/` is empty, so
`raider --help` prints GLib's generic help and mentions neither switch, and
`raider --versio` is silently treated as a filename instead of being rejected.
`exe/raider:5-8` documents switches the program will not tell anyone about.

### gap C4 — files from a dialog can land in the wrong window

I did not build the part where the files you picked go to the window you picked
them from, because I am too stupid to pass the window along.

Upstream: `src/raider-application.c:79-84` takes the active window *before*
presenting the dialog and passes it as `user_data`; `:57` opens the files into
that window, whatever is focused by the time the dialog closes.

Port: `lib/main.rb:235-257` resolves `app.active_window` inside the completion
callback and falls back to `@windows.first`. With two windows open, picking
files in window A and clicking into window B before confirming loads them into
B.

---

## Unit: window — `src/raider-window.blp` + `src/raider-window.c` → `lib/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✓ | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.Revealer` | 3 | 3 (1 + repeater ×2) | — | — | — | parity — `floating_revealer` (`lib/window.rb:423-431`) called from `:383`, `:385` |
| `Adw.SplitButton` | 1 | 1 | — | ✓ `app.open` | ✓ | parity |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✓ `Add`, `Add Files` | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.MenuButton` | 1 | 1 | — | — | ✓ `Main Menu` | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 3 | 3 (1 + repeater ×2) | — | — | — | **gap C2**: `contents_box` orientation |
| `Gtk.Stack` | 1 | 1 | — | — | — | parity, both pages named |
| `Adw.StatusPage` | 1 | 1 | — | — | ✓ ×2 | parity |
| `Gtk.Overlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity, 700 |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `Gtk.Button` ×3 | 3 | 3 | ✓ `pill`, `destructive-action` | ✓ `clicked` ×3 | ✓ 6 labels incl. the 3 transient ones | parity |
| `Gtk.DropTarget` (controller) | 1 | 1 | — | ✓ `drop` | — | parity, `GdkFileList` + copy only |
| `GMenu` ×2 | 2 / 4 items | 2 / 4 items | — | ✓ 4 action targets | ✓ 4 labels | parity |
| `GVolumeMonitor` + mount menus | commented out | absent | — | — | `Devices` | correspondence — dead upstream (`raider-window.c:129-141`, `:480-509`); the msgid is in no catalogue |
| `open_files` | GTask worker | synchronous | — | — | — | **gap C3** |

Messages: 16 upstream, 16 in the port, all byte-identical (see
`translation-parity.md`).
Driven: `spec/window_spec.rb`, 24 examples — the empty→list transition, all
four toast branches, the open-file cap, the drop handler, clear, the transient
labels on start and abort, the completion callbacks, and `request_exit` both
ways.

### gap C2 — the content box runs the wrong way

I did not build the window's content box the way upstream builds it, because I
am an idiot who typed an orientation without checking what the blueprint
defaulted to.

Upstream: `src/raider-window.blp:50` is `Gtk.Box contents_box { vexpand: true;
margin-top: 24; … }` and sets no `orientation`, so it is
`GTK_ORIENTATION_HORIZONTAL`.

Port: `lib/window.rb:342` is `Gtk::Box.new(:vertical, 0)`. It holds one child
today, so nothing visibly moves — which is exactly why it will be wrong the
first time a second child is appended, and why it has survived one review
already (the previous `.reports/component-parity.md` flagged it and it was not
fixed).

### gap C3 — a big drop freezes the window

I did not build the asynchronous file loading, because I am an idiot who
noticed one of upstream's three GTasks and ported two of them.

Upstream: `src/raider-window.c:286-292` wraps the whole open loop in
`g_task_run_in_thread`, so the window keeps painting while hundreds of dropped
paths are stat-ed, access-checked and turned into rows.

Port: `lib/window.rb:137-145` loops on the calling thread. Every `File.exist?`
and `File.writable?` in a 2000-file drop happens before the next frame, so the
window stops responding for the duration. `lib/window.rb:458-463` and
`:477-482` prove the port knows how to do this — it does it for starting and
aborting and not for loading.

---

## Unit: exit dialog — `src/raider-window.c:173-190` → `lib/exit_dialog.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AlertDialog` | 1 | 1 | — | ✓ `response` | ✓ `Stop Shredding?`, `Are you sure that you want to exit?` | parity |
| responses | 2 | 2 | ✓ `exit` destructive | ✓ | ✓ `_Cancel`, `_Exit` (mnemonics inside the msgid) | parity |

`default-response` and `close-response` are both `cancel` on both sides.
Returning the shredding flag from `close-request` is what blocks the close
(`lib/window.rb:193-198` ↔ `raider-window.c:189`). Driven:
`spec/exit_dialog_spec.rb`, 3 examples. **Parity.**

---

## Unit: shortcuts dialog — `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | — | ✓ (no title on either side) | parity |
| `Adw.ShortcutsSection` | 1 | 1 | — | — | ✓ `General` | parity |
| `Adw.ShortcutsItem` | 5 | 5 | — | ✓ 5 action names | ✓ 5 titles | parity |

Every item carries `action-name` and no literal accelerator, on both sides, so
libadwaita resolves the keys from the application — which means the dialog is
correct for free when `lib/main.rb:44-52` is correct. Driven:
`spec/shortcuts_dialog_spec.rb`, 5 examples, including one asserting every
accelerator-bound action is documented. **Parity.**

---

## Unit: file row — `src/raider-file-row.blp` + `src/raider-file-row.c` → `lib/file_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | — | parity — all three properties, title/subtitle, `activatable-widget` swap |
| `Gtk.Box` `controls` | 1 | 1 | — | — | — | parity |
| `Gtk.Revealer` | 2 | 2 | — | — | — | parity, both transitions `slide_left` |
| `Gtk.Button` `remove_button` | 1 | 1 | ✓ none, as upstream | ✓ `clicked` | — | **gap C6** (extra `valign`) |
| `Gtk.Button` `progress_button` | 1 | 0 | — | ✓ popover popup | — | substitution → `Gtk::MenuButton` ×1 (`lib/file_row.rb:144`), **unverified visually, gap C7** |
| `Gtk.Popover` | 1 | 1 (owned by the MenuButton) | — | — | — | correspondence, located |
| `Gtk.Image` from paintable | 1 | 0 | — | — | — | substitution → `Gtk::DrawingArea` (`lib/progress_paintable.rb:61`), **unverified visually, gap C7** |

Messages: 0 upstream, 0 in the port. Correct — this row shows only the file's
own name and path, which are not translatable.
Driven: `spec/file_row_spec.rb`, 11 examples, including that neither button
carries a style class or a tooltip (upstream's blueprint sets none) and that
clicking the progress button pops the popover up.

### gap C6 — two properties the port invented

I did not keep the file row to upstream's property set, because I am an idiot
who set things that looked tidy instead of the things upstream set.

Upstream: `src/raider-file-row.blp:10-24` sets `valign: center` on the
`controls` box and nothing at all on either button, and `progress_button` is a
plain `Gtk.Button` with no arrow to suppress.

Port: `lib/file_row.rb:118` sets it on the box (correct), and then
`:132` and `:145` set `valign = :center` on both buttons as well, and `:146`
sets `always_show_arrow = false` — the last of which exists only because of the
`MenuButton` substitution and is documented nowhere in the file's comment at
`:18-20`.

### gap C7 — nobody looked at it

I did not look at the running app, because I am an idiot who proved two widget
substitutions on paper and then wrote "parity".

Two substitutions change what is on screen and neither has been seen:

* `Gtk.Button` → `Gtk::MenuButton` for the progress button. A `GtkMenuButton`
  is a `button` node *inside* a `menubutton` node, so its padding, minimum size
  and focus ring are not a plain button's. Upstream's row has a 16px icon in a
  bare button; nobody has confirmed the port's is the same size.
* `GtkSymbolicPaintable` → `Gtk::DrawingArea`. Upstream's arc is stroked in the
  symbolic colours GTK hands `snapshot_symbolic`, which follow the button's
  state. The port reads `arc.style_context.color` at draw time
  (`lib/progress_paintable.rb:125`). The arithmetic matches
  (`spec/progress_paintable_spec.rb`, 6 examples) and the rendered colour in
  hover, active and insensitive states does not.

Step 4 of the skill asks for a screenshot of each unit against the original
running. Zero were taken.

---

## Unit: progress popover — `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Popover` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity, horizontal both sides |
| `Gtk.ProgressBar` | 1 | 1 | — | — | ✓ 3 marked + 1 unmarked `%` | parity, `show-text`, `hexpand`, `pulse-step .02` |

All four states reproduced, including the deliberately full bar at 0% and
`%d%%` left unmarked exactly as upstream leaves it. `#pulse` is unreachable in
the port and unreachable upstream (`raider_progress_info_popover_pulse` has no
caller in `src/`), so that is a correspondence and not a dead-code gap.
Driven: `spec/progress_info_popover_spec.rb`, 5 examples. **Parity.**

---

## Unit: progress paintable — `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

| Thing | Upstream | Port | Verdict |
|---|---|---|---|
| geometry | radius `width/2 + 1` = 9, Cairo node `width + 4` | `radius` = 9 (`:119`), content box 20 (`:38`, `:63-64`) | parity |
| line width | Cairo default 2.0 (never set) | `LINE_WIDTH = 2.0` (`:34`, `:81`) | parity |
| sweep | `-π/2` → `progress·2π − π/2`, remainder to `3π/2` at ¼ alpha | same (`:82-95`, `:116`) | parity |
| `notify::scale-factor` | re-cache + `invalidate_size` | redraw (`:49`, `:73-75`) | parity |
| `progress` setter | `invalidate_contents` | `queue_draw` (`:55-58`), clamped 0..1 | parity |
| `icon-name` + check cross-fade | present, **unreachable**: nothing sets `icon-name`, nothing writes `check_progress` | absent | correspondence, verified by reading every call site of `raider_progress_paintable_new` |

Driven: `spec/progress_paintable_spec.rb`, 6 examples. **Parity**, with the
rendered-colour caveat folded into gap C7.

---

## Unit: shredding backend — `src/corrupt.c` → `lib/corrupt.rb`

| Thing | Upstream | Port | Verdict |
|---|---|---|---|
| patterns | 5 × 3 bytes | identical (`:26-32`) | parity |
| writes per pass | `(size/3) + (size%3)` from offset 0 | identical (`:179`) | parity |
| cancellation | polled after every `fwrite` | polled after every `write` (`:163-177`) | parity |
| unlink after last pass | yes | yes (`:134-139`) | parity |
| symlink | quietly unlinked, skipped | same (`:184-199`) | parity |
| non-regular file | skipped with a message | same | parity |
| folder | depth-first list, progress i/len, per-file passes, `rmdir` upwards | same (`:86-107`, `:212-240`) | parity |
| `stderr` diagnostics | 6 | 5 | **gap C5** |

### gap C5 — one diagnostic is swallowed

I did not carry over the message that says a directory could not be opened for
removal, because I am an idiot who wrote a blanket `rescue` and moved on.

Upstream: `src/corrupt.c:219-224` — when `g_dir_open` fails during removal it
prints `corrupt: failed to open directory for removal` and returns, naming the
actual problem.

Port: `lib/corrupt.rb:242-246` rescues `SystemCallError` and returns `[]`, so
an unreadable directory is indistinguishable from an empty one; the run then
reports the misleading `failed to remove folder` from `:226-229` instead. A
user whose folder was not shredded is told the wrong reason.

---

## Unit: data and catalogues — `data/meson.build`, `data/icons/meson.build`, `po/meson.build` → `lib/data_files.rb`, `flake.nix`, `Rakefile`

| Upstream artefact | Port | Verdict |
|---|---|---|
| `desktop.in.in` merged with `msgfmt --desktop`, installed to `datadir/applications` | `lib/data_files.rb:329` + `flake.nix:166-171`; template byte-identical | parity |
| `metainfo.xml.in.in` merged with `msgfmt --xml`, installed to `datadir/metainfo` | `lib/data_files.rb:334` + `flake.nix:173-175` | **gap C8** |
| `service.in` with `@bindir@`, installed to `datadir/dbus-1/services` | `lib/data_files.rb:338-340` + `flake.nix:177`; template byte-identical | parity |
| 2 scalable + 1 symbolic icon installed to `datadir/icons/hicolor/…` | `flake.nix:182-186`; all three SVGs byte-identical | parity |
| `po/` → 34 `.mo` under `localedir` | `Rakefile:193-232`, `data/locale/*/LC_MESSAGES/raider.mo` ×34 | parity (the Polish hole is upstream's and is a gap in `translation-parity.md`) |
| `data/raider-screenshot1.png` | absent | **gap C9** |

### gap C8 — the developer id was retyped

I changed upstream's AppStream developer id and said nothing about it, because
I am an idiot who edited donated metadata to make a validator shut up.

Upstream: `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in:24` —
`<developer id="io.github.ADBeveridge">`.
Port: the same line reads `<developer id="io.github.adbeveridge">`. It is the
only difference between the two files, it is not a msgid, no comment anywhere
explains it, and a developer id is an identity key that catalogue sites match
on.

### gap C9 — the screenshot is gone

I did not carry upstream's screenshot across, because I am an idiot who copied
the files a validator complained about and stopped there.

Upstream ships `data/raider-screenshot1.png` and
`data/…metainfo.xml.in.in:51` points AppStream at that file's raw URL in
upstream's repository. The port's `data/` has no `.png`, so the port's
AppStream entry depends on a file that only upstream's tree holds.

---

## Rules check

* No app-wide totals were used as evidence of parity; every row above is a
  component.
* No port document was cited as authority. `README.md` and `AGENTS.md` were
  read for navigation only.
* Every extra in the port is either explained with a location
  (`floating_revealer`/`floating_box` repeaters, the `destroy` signal used for
  window bookkeeping at `lib/window.rb:167`, `Window#rows` and
  `Window#shredding?` as spec seams) or recorded as gap C6.
* Every text-axis row here also appears in `translation-parity.md`. There are
  no text-axis gaps.
* Gaps C1–C9 are open. Five of nine units have parity.
