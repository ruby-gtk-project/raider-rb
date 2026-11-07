# Component identification — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `4c759f350accd7b709978af2afc4dc56d0bc0dc8` |
| Method | `component-identification/scripts/component-scan.sh` on both trees (upstream extracted with `git archive origin/main`), then every file read by hand |
| Re-run this audit | `git diff ff5772c..4c759f3 -- lib/ exe/` touches exactly three files (`lib/progress_paintable.rb`, `lib/shortcuts_dialog.rb`, `lib/translation.rb`) and every changed line is a comment — no widget, action, signal connection, CSS class or string was added, removed or renamed anywhere in `lib/` or `exe/` since the inventory was last taken at `ff5772c`. The rest of this document is therefore unchanged from that pass, re-verified line by line against the current tree rather than carried forward blind. |

## Step 1 — the declarative files

Upstream has four `.blp` files, and they are the unit list:

| Declarative file | Root | Unit |
|---|---|---|
| `src/raider-window.blp` | `template $RaiderWindow : Adw.ApplicationWindow` | window |
| `src/raider-file-row.blp` | `template $RaiderFileRow : Adw.ActionRow` | file row |
| `src/raider-progress-info-popover.blp` | `template $RaiderProgressInfoPopover : Gtk.Popover` | progress popover |
| `src/raider-shortcuts.blp` | `Adw.ShortcutsDialog shortcuts_dialog` (named root, no `template`, no backing source) | shortcuts dialog |

Two menu models live inside `raider-window.blp` and produce no scan rows,
being all lowercase keywords: `primary_menu` (2 sections, 3 items —
`win.show-shortcuts`, `win.about`, `app.quit` is on the window's own
`close-request` path, not the menu) and `open_menu` (1 section, 1 item,
`app.open-folder`). Counted by hand against the blueprint text.

The port has no `.blp`/`.ui` files; every widget is a memoized accessor
built with `.tap`, which is the house declarative style this org's pilot
port set.

## File mapping (unioned before any comparison)

```
src/main.c + src/raider-application.c              -> lib/main.rb + exe/raider + lib/package_config.rb
src/raider-window.blp + src/raider-window.c        -> lib/window.rb + lib/exit_dialog.rb
src/raider-file-row.blp + src/raider-file-row.c    -> lib/file_row.rb
src/raider-progress-info-popover.blp + .c          -> lib/progress_info_popover.rb
src/raider-shortcuts.blp                           -> lib/shortcuts_dialog.rb
src/raider-progress-paintable.c                    -> lib/progress_paintable.rb
src/corrupt.c                                      -> lib/corrupt.rb
data/meson.build + data/icons/meson.build          -> lib/data_files.rb + flake.nix installPhase
po/meson.build + src/main.c gettext calls          -> lib/translation.rb + Rakefile gettext tasks
```

`src/meson.build`, `src/raider.gresource.xml` and the top-level
`meson.build` have no counterpart file, by the nature of the port (no
GResource to compile, no meson build to replace) — this is a build-system
fact, not a missing unit, and is treated as such rather than silently
dropped from the mapping.

11 units total, matching the runtime drive's own count (`test/drive_main_window.rb`
drives "11 components" per its own header, confirmed this audit by running
it — see `component-parity.md` and `test-parity.md`).

## Per-unit inventory

### `src/raider-application.c` + `src/main.c` → `lib/main.rb` + `exe/raider`

| Thing | × | CSS | Signals/Actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` (ported as `Gtk::Application` + manual `Adwaita.init`) | 1 | — | `activate`, `open` | `Adwaita::Application` subclassing raises in this binding — documented in `KNOWN_LIMITATIONS.md` |
| `Adw.AboutDialog` | 1 | — | — | 11 fields incl. `translator-credits` |
| `Gtk.FileDialog` | 2 (open files, open folder) | — | completion callback | |
| actions | `quit`, `new-window`, `open`, `open-folder`, `about`, `show-shortcuts`, `close` = 7, plus libadwaita's own `app.quit` style defaults | — | 7 installed, each with an accelerator | `win.close` is accelerator `<Ctrl>w`; `app.quit` is `<Ctrl>q` |
| `GOptionEntry` | 2 (`--version`/`-v`, `--new-window`/`-w`) | — | — | upstream registers both through `g_application_add_main_option_entries`; the port reads `ARGV` by hand instead — see `component-parity.md` gap C1 |

### `src/raider-window.blp` + `.c` → `lib/window.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` | 800×600 default, 270×300 minimum |
| `Gtk.Revealer` | 3 (1 top-level + a 2-state repeater) | — | — | `floating_revealer` plus the empty-state/list-state pair |
| `Gtk.Box` (`contents_box`) | 1 (holds the repeated rows) | — | — | horizontal, unset orientation upstream |
| `Adw.ToastOverlay` | 1 | — | — | duplicate/limit/error toasts |
| `Gtk.DropTarget` | 1 | — | `drop` | file-list GType |
| `open_files`/`open_file` | — | — | — | upstream runs this in a `GTask` worker thread; the port runs it synchronously — gap C3 |

### `src/raider-window.c:173-190` → `lib/exit_dialog.rb`

`Adw.AlertDialog`, 1, two responses (`cancel`, `exit` — `exit` carries the
`destructive-action` appearance), `response` signal, two marked strings
with mnemonics inside the msgid.

### `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

`Adw.ShortcutsDialog` → `Adw.ShortcutsSection` ("General") → 5
`Adw.ShortcutsItem`s, each naming an action rather than a literal
accelerator.

### `src/raider-file-row.blp` + `.c` → `lib/file_row.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title/subtitle = filename/path |
| `Gtk.Box` (`controls`) | 1 | — | — | `valign: center` |
| `Gtk.Revealer` | 2 | — | — | both `slide_left` |
| `Gtk.Button` (remove) | 1 | — | `clicked` | |
| `Gtk.Button` (progress, upstream) / `Gtk.MenuButton` (port) | 1 | — | popover popup | **substitution** — upstream's button hosts a `GtkSymbolicPaintable`; the port's `MenuButton` draws its own disclosure arrow, which upstream's plain button does not |
| `Gtk.Image` (upstream) / `Gtk.DrawingArea` (port) | 1 | — | — | **substitution**, see progress paintable below |

### `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`

`Gtk.Popover` → `Gtk.ProgressBar` (`show-text`, `hexpand`, `pulse-step .02`)
+ one label. 3 marked strings, 1 unmarked `%d%%` (unmarked on both sides).

### `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

A `GdkPaintable`/`GtkSymbolicPaintable` GObject in C, substituted with a
`Gtk::DrawingArea` that issues the same Cairo calls by hand — Ruby-GNOME has
no supported path to implement a GI interface's vfuncs and have GTK call
back into them during its paint cycle (`KNOWN_LIMITATIONS.md`). This is the
same substitution gap flagged against the file row's progress button above;
one architectural divergence, two components.

### `src/corrupt.c` → `lib/corrupt.rb`

Five fixed byte patterns, regular file, zero-byte file, folder tree
(recursive), cancellation, `stderr` diagnostics on open/listing/write
failure. No widget, pure backend logic.

### `data/`, `po/` → `data/`, `po/`, `lib/data_files.rb`

Desktop entry, metainfo (with screenshot `<image>`), D-Bus service file,
three icon sizes, 35 `.po` + 1 `.pot`, `LINGUAS`. See `translation-parity.md`
for the message-level census.

## Rules check

- No widget type is listed without its CSS classes and signals where either
  exists; a bare "—" means genuinely none on either side, confirmed by
  reading the `.blp`/`.c` source, not assumed.
- Both substitutions (progress button, progress paintable) are recorded as
  components in their own right, not silently merged into "the same gap."
- Menu models and their `item` entries are counted by hand since the scan
  cannot see lowercase blueprint keywords.
