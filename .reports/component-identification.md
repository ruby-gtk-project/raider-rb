# Component identification — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Method | `component-identification/scripts/component-scan.sh` on both trees, symbol table present (1301 rows), then every file read |

Upstream has four declarative files, so Step 1 of the skill gives the unit list
for free:

| Declarative file | Root | Unit |
|---|---|---|
| `src/raider-window.blp` | `template $RaiderWindow : Adw.ApplicationWindow` | window |
| `src/raider-file-row.blp` | `template $RaiderFileRow : Adw.ActionRow` | file row |
| `src/raider-progress-info-popover.blp` | `template $RaiderProgressInfoPopover : Gtk.Popover` | progress popover |
| `src/raider-shortcuts.blp` | `Adw.ShortcutsDialog shortcuts_dialog` (no template, no backing source) | shortcuts dialog |

Plus the three units no `.blp` owns: the application class
(`src/main.c` + `src/raider-application.c`), the alert dialog
`raider_window_exit` builds in source only, the progress paintable
(`src/raider-progress-paintable.c`), the shredding backend
(`src/corrupt.c`), and the installable data the build file produces
(`data/meson.build`, `data/icons/meson.build`, `po/meson.build`).

The port has **no** `.blp`/`.ui` files, as the house style intends; every
widget is a memoized accessor.

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

Corrections made by hand before trusting the union, per Step 2:

* The template root is counted twice — `src/raider-window.c` declares
  `AdwApplicationWindow parent_instance` and `src/raider-window.blp` declares
  `template $RaiderWindow : Adw.ApplicationWindow`. Struck one.
  Same for `Adw.ActionRow` (file row) and `Gtk.Popover` (popover).
* `lib/exit_dialog.rb` has no upstream file of its own: it is the alert dialog
  built inline at `src/raider-window.c:177-185`.
* `lib/data_files.rb`, `lib/package_config.rb` and `lib/translation.rb` have no
  upstream *source* file; they answer `data/meson.build`, the `config_h` block
  in `meson.build` and `po/meson.build` respectively.

## Whole-app totals

| Axis | Upstream distinct | Port distinct |
|---|---:|---:|
| widget types | 20 | 20 |
| controller types | 1 (`Gtk.DropTarget`) | 1 |
| CSS classes | 3 (`boxed-list`, `destructive-action`, `pill`) | 3 |
| signals | 11 | 10 + 1 extra (`destroy`) |
| actions | 8 literals, 6 installed | 7 installed |

Neither tree has a `.css` file and neither loads a `Gtk::CssProvider`
(`grep -rn 'CssProvider\|load(data:' lib/` is empty). The three classes in play
are all platform classes that GTK and libadwaita define, so the stylesheet half
of the CSS axis is vacuous here — the whole CSS question is which classes the
port *attaches*, which `component-parity.md` answers.

## Inventories

### `src/main.c` + `src/raider-application.c` → `lib/main.rb` — the application

| Thing | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` (`Gtk::Application` in the port) | 1 | — | `activate`, `open` vfuncs | `G_APPLICATION_HANDLES_OPEN`; port calls `Adwaita.init` itself (`lib/main.rb:92`) in place of `AdwApplication`'s own init |
| `Adw.AboutDialog` | 1 | — | — | 11 fields set, including `translator-credits` |
| `Gtk.FileDialog` | 2 | — | — | one per action: `open` (multiple files), `open-folder` (multiple folders) |
| `Gio.SimpleAction` | 6 up / 7 port | — | `activate` ×6/×7 | see the action table |
| `GOptionEntry` | 2 | — | — | `-w/--new-window`, `-v/--version`; **no counterpart in the port**, see gap A1 |

Actions (the scan's least trustworthy stream, so read off every install site):

| Action | Accel | Upstream install site | Port |
|---|---|---|---|
| `app.open` | `<Ctrl>o` | `raider-application.c:281-284` | `lib/main.rb:45` |
| `app.open-folder` | — | `:286-288` | `:46` |
| `app.new-window` | `<Ctrl>n` | `:276-279` | `:47` |
| `app.close` | `<Ctrl>w` | `:267-270` | `:48` |
| `app.quit` | `<Ctrl>q` | `:262-265` | `:49` |
| `app.about` | — | `:272-274` | `:50` |
| `app.shortcuts` | `<Ctrl>question` | **not installed upstream** — referenced from `raider-window.blp:144` and `raider-shortcuts.blp:16`, supplied by libadwaita because `src/raider.gresource.xml:7` aliases the dialog as `shortcuts-dialog.ui` | `:51`, installed by hand |
| `app.open-drive` | — | commented out, `raider-application.c:125-139`, `:291-293` | absent on both sides |

The `app.shortcuts` correspondence is verified, not asserted:
`strings libadwaita-1.so.0` carries `shortcuts-dialog.ui`, `app.shortcuts` and
`<Control>question` adjacently (libadwaita 1.9.3), which is where upstream's
binding comes from and what the port reproduces by installing the action
itself.

### `src/raider-window.blp` + `src/raider-window.c` → `lib/window.rb` — the one window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` | 800×600, min 270×300, `icon-name` = app id, title `_("File Shredder")` |
| `Adw.ToolbarView` | 1 | — | — | `vexpand` |
| `Adw.HeaderBar` | 1 | — | — | `centering-policy: strict` |
| `Gtk.Revealer` | 3 | — | — | `open_revealer` (slide_right, revealed), `shred_revealer` + `abort_revealer` (slide_up, hidden, valign end, halign center, margin-bottom 20). The port factors the latter two into one `floating_revealer` helper — a repeater, two call sites |
| `Adw.SplitButton` | 1 | — | — | `action-name: app.open`, `menu-model: open_menu` |
| `Adw.ButtonContent` | 1 | — | — | label `_("Add")`, icon `document-open-symbolic`, tooltip `_("Add Files")` |
| `Adw.WindowTitle` | 1 | — | — | `_("File Shredder")` |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, tooltip `_("Main Menu")`, `primary: true`, `primary_menu` |
| `Adw.ToastOverlay` | 1 | — | — | every error state in this app is a toast |
| `Gtk.Box` | 3 | — | — | `contents_box` (**horizontal** upstream, `vexpand`, margin-top 24) + the two floating button boxes (horizontal, margin 5 all round) |
| `Gtk.Stack` | 1 | — | — | `crossfade`; two named pages `empty_page`, `list_page` |
| `Adw.StatusPage` | 1 | — | — | the empty state: title `_("Add files or drop here")`, app icon, the long `_("Shredding is the obfuscation…")` description, `hexpand` |
| `Gtk.Overlay` | 1 | — | — | holds the scroller plus the two floating revealers |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | `maximum-size: 700` |
| `Gtk.ListBox` | 1 | `boxed-list` | — | `valign: start`, 12px margins; made insensitive while aborting |
| `Gtk.Button` | 3 | `pill` (clear); `destructive-action`+`pill` (shred, abort) | `clicked` ×3 | labels `_("Clear")`, `_("Shred All")` (margin-start 10), `_("Abort All")` |
| `Adw.AlertDialog` | 1 | — | `response` | built in source, not the `.blp` → `lib/exit_dialog.rb` |
| `Adw.Toast` (type, not widget) | 1 | — | — | five distinct toast messages |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` | `GdkFileList`, `GDK_ACTION_COPY`, installed on `contents_box` |
| `GMenu` | 2 | — | — | `primary_menu` (2 sections, 3 items), `open_menu` (1 section, 1 item) |
| `GVolumeMonitor` + 2 `GMenu`s | — | — | `mount-added`, `mount-changed`, `mount-removed` | **commented out upstream** (`raider-window.c:129-141`, `:480-509`); the only source of the msgid `Devices`, which appears in no catalogue |

Repeaters: `FileRow`, one per loaded file, driven by the window's file list.
Conditional: the `list_page` child only once a file loads; the three revealers
are state, not conditionals.

Dynamic labels (same widget, different text by state): `shred_button` is
`Shred All` → `Starting Shredding…` → `Shred All`; `clear_button` is `Clear` →
`Clear All` after a shred run (upstream never puts `Clear` back —
`raider-window.c:387`); `abort_button` is `Abort All` → `Aborting…` →
`Abort All`.

### `src/raider-file-row.blp` + `src/raider-file-row.c` → `lib/file_row.rb` — one file in the list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | `selectable: false`, `activatable: true`, `use-markup: false`; title = basename, subtitle = full path; `activatable-widget` becomes the progress button while shredding |
| `Gtk.Box` `controls` | 1 | — | — | `[suffix]`, `valign: center` |
| `Gtk.Revealer` | 2 | — | — | `remove_revealer` (slide_left, revealed), `progress_revealer` (slide_left, hidden) |
| `Gtk.Button` `remove_button` | 1 | — | `clicked` → `raider_file_row_close` | icon `edit-delete-symbolic`, no style class, no tooltip |
| `Gtk.Button` `progress_button` | 1 | — | `clicked` → `gtk_popover_popup` (swapped) | no label, no icon; its child is the progress image. **Port substitutes `Gtk::MenuButton`** (`lib/file_row.rb:144`) |
| `Gtk.Popover` | 1 | — | — | `RaiderProgressInfoPopover`, parented to the progress button by hand upstream |
| `Gtk.Image` | 1 | — | — | `gtk_image_new_from_paintable(progress_paintable)`. **Port substitutes a `Gtk::DrawingArea`** (`lib/progress_paintable.rb:61`) |

### `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` | 1 | — | — | template root |
| `Gtk.Box` `popover_box` | 1 | — | — | horizontal (default) |
| `Gtk.ProgressBar` | 1 | — | — | `show-text`, `hexpand`, `pulse-step .02` |

Four text states, all in the bar's own text: `_("Starting…")` with a
deliberately **full** bar at 0, `"%d%%"` (unmarked on both sides) in between,
`_("Finishing up…")` pulsing at 100, and `_("Estimating…")` from
`raider_progress_info_popover_pulse` — which nothing upstream calls, and
nothing in the port calls either.

### `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

| Widget | × | Notes |
|---|---:|---|
| `Adw.ShortcutsDialog` | 1 | no title set on either side — libadwaita's own translated default |
| `Adw.ShortcutsSection` | 1 | `_("General")` |
| `Adw.ShortcutsItem` | 5 | `app.open`/`_("Add Files")`, `app.new-window`/`_("New Window")`, `app.shortcuts`/`_("Keyboard Shortcuts")`, `app.close`/`_("Close Window")`, `app.quit`/`_("Quit")` — each names its action, never a key, so libadwaita resolves the accel from the application |

### `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

No widget upstream: a `GObject` implementing `GdkPaintable` and
`GtkSymbolicPaintable`, properties `icon-name`, `widget` (construct-only),
`progress`; `notify::scale-factor` on the host widget re-caches and invalidates
the size. `snapshot_symbolic` strokes the completed sweep from -π/2 in the
first symbolic colour and the remainder to 3π/2 at a quarter alpha, both at
radius `width/2 + 1`, into a Cairo node of `width + 4`.

`icon-name` is never set by any caller (`raider_progress_paintable_new` passes
only `widget`) and `check_progress` is never written, so both check-icon
branches of `snapshot_symbolic` are unreachable upstream.

### `src/corrupt.c` → `lib/corrupt.rb`

No UI. Five three-byte patterns, `(size/3)+(size%3)` writes per pass from
offset 0, cancellable polled after every write, unlink after the last pass.
Folders: depth-first file list, progress = i/len, then `rmdir` upwards. Six
`stderr` diagnostics.

### `data/meson.build`, `data/icons/meson.build`, `po/meson.build` → `lib/data_files.rb`, `flake.nix`, `Rakefile`

Not widgets, but they are where the launcher entry, the AppStream metadata,
D-Bus activation, the icons and all 34 compiled catalogues come from — and two
of upstream's three declared `test()`s live here. `flake.nix:140-186` is the
port's install step; `lib/data_files.rb` is the merge step; the `Rakefile`
gettext tasks are `po/meson.build`.
