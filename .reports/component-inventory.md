# Component inventory — raider (File Shredder) → raider-rb

Survey for the full-parity port. One section per upstream component, in the
order a user meets it. Produced with the `component-identification` skill:
`.blp` files read first (they are the widget tree, the CSS classes and the
counts, already correct), then the `.c` files for everything built at runtime,
then the scan as a cross-check.

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `f98a795e289c3530ea30fd94cff2c5041e9725f6` |
| Symbol table | `.claude/skills/component-identification/scripts/symbols.tsv`, 1301 rows |
| Upstream UI source | 4 blueprints, 1 GResource manifest, no GSettings schema |
| Catalogues | `po/LINGUAS` = 34 languages over 35 `po/*.po`; the port's `LINGUAS` is byte-identical to upstream's and its `po/*.po` membership is identical |

## Unit map

| # | Upstream files | → port file | Kind | Exists |
|---|---|---|---:|---|
| 1 | `src/main.c`, `src/raider-application.c`/`.h` | `lib/main.rb` (`App`) | application, actions, accelerators, About dialog, CLI options | yes |
| 2 | `src/raider-window.blp`, `src/raider-window.c`/`.h` | `lib/window.rb` (`Window`) | main window, header bar, stack, empty state, list page, toasts, menus, drop target | yes |
| 3 | alert dialog built inline in `raider_window_exit` (`src/raider-window.c`) | `lib/exit_dialog.rb` (`ExitDialog`) | dialog (error/confirm state) | yes |
| 4 | `src/raider-file-row.blp`, `src/raider-file-row.c`/`.h` | `lib/file_row.rb` (`FileRow`) | list row (repeater, one per loaded file) | yes |
| 5 | `src/raider-progress-info-popover.blp`, `src/raider-progress-info-popover.c`/`.h` | `lib/progress_info_popover.rb` (`ProgressInfoPopover`) | popover | yes |
| 6 | `src/raider-progress-paintable.c`/`.h` | `lib/progress_paintable.rb` (`ProgressPaintable`) | custom drawing (progress arc) | yes |
| 7 | `src/raider-shortcuts.blp` (standalone, no backing source) | `lib/shortcuts_dialog.rb` (`ShortcutsDialog`) | keyboard-shortcuts dialog | yes |
| 8 | `src/corrupt.c`/`.h` | `lib/corrupt.rb` (`Corrupt`) | non-UI backend | yes |
| 9 | `meson.build` `config_h` block | `lib/package_config.rb` | non-UI build constants | yes |
| 10 | `po/meson.build`, gettext calls in `src/main.c` | `lib/translation.rb` | non-UI i18n binding | yes |
| 11 | `data/meson.build` (desktop, metainfo, service) | `lib/data_files.rb` | non-UI installable data | yes |
| — | `src/raider.gresource.xml` | — | GResource manifest. Every one of the four `.blp` files it lists is covered by units 2, 4, 5 and 7; it holds no component of its own. Located, not excused | — |
| — | `src/raider-window.c:129-141`, `:453-487`, `raider_application_open_drive` | — | drive/mount menu inside a `/* … */` block, so nothing it declares is compiled and its one msgid (`Devices`) reaches no `.pot` and no `.po` — evidence in `translation-parity.md`. Located dead block | — |

Nothing in upstream maps to a port file that does not exist, and no
`lib/*.rb` exists that upstream does not account for.

---

## 1. `src/main.c` + `src/raider-application.c` — the application

→ `lib/main.rb` (`App`). **Exists.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` (port: `Gtk::Application` + `Adwaita.init`) | 1 | — | `activate`, `open` | `HANDLES_OPEN`; `open` gives the files a window of their own |
| `Adw.AboutDialog` | 1 | — | — | `adw_show_about_dialog`; built fresh per invocation |
| `Gtk.FileDialog` | 2 | — | — | modal; "Add Files" (`open_multiple`) and "Add Folders" (`select_multiple_folders`) |

Actions installed here (the scan's `action` stream under-reports — the port
builds all seven from a loop over `ACTIONS`, so no name is a literal):

| Action | Accel (upstream) | Port | Handler |
|---|---|---|---|
| `app.open` | `<Ctrl>o` | yes | file dialog → `Window#open_files` |
| `app.open-folder` | none | yes | folder dialog → `Window#open_files` |
| `app.new-window` | `<Ctrl>n` | yes | new `Window` |
| `app.close` | `<Ctrl>w` | yes | close active window |
| `app.quit` | `<Ctrl>q` | yes | `try_exit` — asks every window, quits only if none is shredding |
| `app.about` | none | yes | About dialog |
| `app.shortcuts` | — | yes, `<Ctrl>question` | substitution, located: upstream gets this action and accel from libadwaita's `shortcuts-dialog.ui` GResource alias; the port has no GResource, so it installs the same action name with the same accel itself at `lib/main.rb:51` |
| `app.open-drive` | — | — | declared only inside the commented-out block above; not compiled in upstream's own build |

CLI options (`handle_local_options`): `--new-window`/`-w` (forwarded to a
running instance when remote) and `--version`/`-v`. Both ported; everything
else is passed through to GApplication, which is what keeps
`--gapplication-service` working for `data/*.service.in`.

About-dialog fields: application name (translated "File Shredder"), icon,
version, `© 2024 Alan Beveridge`, issue URL, GPL-3.0, developer name, 1
developer, 2 artists, 1 designer, `translator-credits`. All present.

## 2. `src/raider-window.blp` + `src/raider-window.c` — the main window

→ `lib/window.rb` (`Window`). **Exists.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` → `raider_window_exit` | 800×600, min 270×300, title "File Shredder", app icon |
| `Adw.ToolbarView` | 1 | — | — | `vexpand` |
| `Adw.HeaderBar` | 1 | — | — | `centering-policy: strict` |
| `Gtk.Revealer` (`open_revealer`) | 1 | — | — | `slide_right`, revealed; hidden while shredding |
| `Adw.SplitButton` (`open_button`) | 1 | — | — | `action-name: app.open`, `menu-model: open_menu` |
| `Adw.ButtonContent` | 1 | — | — | "Add", `document-open-symbolic`, tooltip "Add Files" |
| `Adw.WindowTitle` | 1 | — | — | "File Shredder" |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, tooltip "Main Menu", `primary`, `primary_menu` |
| `Adw.ToastOverlay` | 1 | — | — | host for all five toasts |
| `Gtk.Box` (`contents_box`) | 1 | — | — | `vexpand`, `margin-top: 24`; carries the drop target |
| `Gtk.Stack` | 1 | — | — | `crossfade`; pages `empty_page`, `list_page` |
| `Adw.StatusPage` (`empty_state`) | 1 | — | — | **empty state:** "Add files or drop here", app icon, description |
| `Gtk.Overlay` | 1 | — | — | list page |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | `maximum-size: 700` |
| `Gtk.ListBox` | 1 | `boxed-list` | — | margins 12 all round, `valign: start`; desensitised while aborting |
| `Gtk.Revealer` (`shred_revealer`) | 1 | — | — | `slide_up`, bottom-centre overlay, `margin-bottom: 20` |
| `Gtk.Revealer` (`abort_revealer`) | 1 | — | — | same geometry |
| `Gtk.Box` (floating, ×2) | 2 | — | — | margins 5; one per revealer |
| `Gtk.Button` (`clear_button`) | 1 | `pill` | `clicked` → `clear_files` | label flips "Clear" → "Clear All" after a shred launch |
| `Gtk.Button` (`shred_button`) | 1 | `destructive-action`, `pill` | `clicked` → `start_shredding` | `margin-start: 10`; transient label "Starting Shredding…" |
| `Gtk.Button` (`abort_button`) | 1 | `destructive-action`, `pill` | `clicked` → `abort_shredding` | transient label "Aborting…" |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → `on_drop` | `GdkFileList` only, `GDK_ACTION_COPY`, attached to `contents_box` |

Menus (all lowercase in blueprint, so invisible to the scan — counted by hand):

| Menu | Sections | Items |
|---|---:|---|
| `primary_menu` | 2 | "New Window" → `app.new-window`; "Keyboard Shortcuts" → `app.shortcuts`; "About File Shredder" → `app.about` |
| `open_menu` | 1 | "Open Folder" → `app.open-folder` |

Both present in the port as `Gio::Menu` with the same section split. No
`custom:` slots.

Repeaters: `FileRow`, one per loaded file, appended to `list_box`.
Conditional: the stack flips to `list_page` on the first row and back to
`empty_page` when the last one goes.

**Error / rejection states** — five toasts, all ported:
"This file was already added", "Some files did not exist",
`Cannot write to “%s”`, "Cannot load more files" (at half `RLIMIT_NOFILE`),
and "Finished shredding files" (a `GNotification` instead when the window is
not active). The fatal "Could not remove filename from quick list. Please
report this." is upstream's `g_error`; the port raises `Window::UnknownRow`.

## 3. The exit alert dialog

→ `lib/exit_dialog.rb` (`ExitDialog`). **Exists.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AlertDialog` | 1 | — | `response` → `raider_window_exit_response` | "Stop Shredding?" / "Are you sure that you want to exit?" |

Responses `cancel` ("_Cancel", default **and** close response) and `exit`
("_Exit", `ADW_RESPONSE_DESTRUCTIVE`). Shown only when shredding is in
flight; `exit` aborts every row and destroys the window. Mnemonic
underscores are part of the msgid.

## 4. `src/raider-file-row.blp` + `src/raider-file-row.c` — one file in the list

→ `lib/file_row.rb` (`FileRow`). **Exists.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | `selectable: false`, `activatable: true`, `use-markup: false`; title = basename, subtitle = full path; `activatable-widget` set to the progress button while shredding and cleared on abort |
| `Gtk.Box` (`controls`) | 1 | — | — | `[suffix]`, `valign: center` |
| `Gtk.Revealer` (`remove_revealer`) | 1 | — | — | `slide_left`, revealed |
| `Gtk.Button` (`remove_button`) | 1 | — | `clicked` → `raider_file_row_close` | `edit-delete-symbolic`; no style, no tooltip upstream |
| `Gtk.Revealer` (`progress_revealer`) | 1 | — | — | `slide_left`, hidden |
| `Gtk.Button` (`progress_button`) | 1 | — | `clicked` → `gtk_popover_popup` (swapped) | **deviation, deliberate:** the port uses `Gtk::MenuButton` with `always_show_arrow = false`, so the popover is owned rather than hand-parented |
| `Gtk.Image` | 1 | — | — | holds the progress paintable; the port's `ProgressPaintable` is itself a `Gtk::DrawingArea`, so there is no separate image |

The two revealers cross-fade: launching shredding hides remove and shows
progress, aborting reverses it.

## 5. `src/raider-progress-info-popover.blp` + `.c` — per-file progress

→ `lib/progress_info_popover.rb` (`ProgressInfoPopover`). **Exists.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` | 1 | — | — | template root |
| `Gtk.Box` (`popover_box`) | 1 | — | — | |
| `Gtk.ProgressBar` | 1 | — | — | `show-text`, `hexpand`, pulse step `.02` |

Four states, all ported: 0% → "Starting…" with the bar deliberately full;
0<x<100 → `"%d%%"` at the fraction; 100% → "Finishing up…" pulsing;
`pulse` → "Estimating…" pulsing.

## 6. `src/raider-progress-paintable.c` — the progress arc

→ `lib/progress_paintable.rb` (`ProgressPaintable`). **Exists.**

Not a widget upstream: a `GObject` implementing `GdkPaintable` +
`GtkSymbolicPaintable`, 16px intrinsic, properties `icon-name`, `widget`
(construct-only), `progress`. Signal `notify::scale-factor` on the host
widget re-caches icons. The port renders it as a `Gtk::DrawingArea` making
the same two `cairo_arc` strokes at radius `width/2 + 1` — the swept part in
the foreground colour, the remainder at 0.25 alpha — sized 20px so the ring
is not clipped.

The `check_paintable` / `check_progress` branch is **dead upstream**:
`raider_progress_paintable_new` passes only `widget`, so `icon-name` stays
`NULL` and `check_progress` is never written — read at `:248`, `:252`, `:257`, `:261`, assigned nowhere. Absent from the port; the evidence is in `component-parity.md`, unit "progress paintable".

## 7. `src/raider-shortcuts.blp` — keyboard shortcuts

→ `lib/shortcuts_dialog.rb` (`ShortcutsDialog`). **Exists.**

Standalone blueprint with a named root (`Adw.ShortcutsDialog
shortcuts_dialog`), not a `template`, aliased into the GResource as
`shortcuts-dialog.ui` — which is what hands GTK the `app.shortcuts` action.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ShortcutsDialog` | 1 | — | — | title is libadwaita's translated default; upstream sets none |
| `Adw.ShortcutsSection` | 1 | — | — | "General" |
| `Adw.ShortcutsItem` | 5 | — | — | "Add Files"/`app.open`, "New Window"/`app.new-window`, "Keyboard Shortcuts"/`app.shortcuts`, "Close Window"/`app.close`, "Quit"/`app.quit` |

All five present, by action name rather than literal keys, so the accelerator
is resolved from the application.

## 8–11. Non-UI units

| Upstream | → port | Exists | Notes |
|---|---|---|---|
| `src/corrupt.c`/`.h` | `lib/corrupt.rb` | yes | pattern passes, folder walk, cancellable |
| `meson.build` `config_h` | `lib/package_config.rb` | yes | `PACKAGE_VERSION` 3.1.0, gettext package, localedir |
| `po/meson.build` + `src/main.c` gettext calls | `lib/translation.rb` | yes | one `raider` domain bound on a module |
| `data/meson.build` | `lib/data_files.rb` | yes | desktop (`msgfmt --desktop`), metainfo (`msgfmt --xml`), service (`configure_file`) |
| `data/icons/**` | `data/icons/**` | yes | all three SVGs present on `ruby` |
| `po/*.po`, `LINGUAS`, `POTFILES` | `po/**` | yes | 35 catalogues (34 listed in `LINGUAS`), membership identical to upstream |

---

## Gaps

None. Every upstream user-facing component has a `lib/*.rb` and every
`lib/*.rb` traces to an upstream file. The three differences are deliberate
and documented in the port's own class comments:

1. `progress_button` is a `Gtk::MenuButton`, not a `Gtk::Button` with a
   hand-parented `Gtk::Popover`.
2. `ProgressPaintable` is a `Gtk::DrawingArea` rather than a
   `GdkPaintable` implementation in a `Gtk::Image`.
3. `app.shortcuts` and its `<Ctrl>question` accelerator are installed
   explicitly, because there is no GResource alias to make GTK supply them.

## Known scanner artefacts

* `raider-window.c` and `raider-window.blp` both report
  `Adw.ApplicationWindow 1` — one window. Likewise `Adw.ActionRow` across
  `raider-file-row.c`/`.blp` and `Gtk.Popover` across
  `raider-progress-info-popover.c`/`.blp`. Union the two files per unit.
* `raider-application.c signal activate 7` is six `GSimpleAction` `activate`
  connections plus the application's own `activate` vfunc.
* `raider-window.c signal mount-added|mount-changed|mount-removed` come from
  the commented-out `GVolumeMonitor` block at `:129-141`. Dead upstream.
* `raider-progress-paintable.c widget Gtk.Widget 1` is the construct-only
  `widget` property's type, not a widget that file builds.
* `lib/window.rb widget Adw.ApplicationWindow 2` / `Gtk.ApplicationWindow 1`
  is one real construction plus the class comment explaining the choice; same
  shape for `lib/main.rb`'s `Gtk.Application`/`Adw.Application`,
  `lib/shortcuts_dialog.rb`'s `Adw.ShortcutsDialog` (superclass + comment) and
  `lib/progress_paintable.rb`'s `Gtk.DrawingArea`.
* `lib/window.rb action app.open 2` under-reports badly: the port installs all
  seven actions from a loop over `ACTIONS` (`lib/main.rb:44-52`, `:173-185`),
  so none of the names is a literal at an install site. The action table above
  was read off the install site.
* Revealers and boxes in `lib/window.rb` are built by the `floating_revealer`
  and `floating_box` helpers, so the scan's count of 2 is two call sites and
  three widgets on screen — matching the blueprint's 3.
* Blueprint `menu` blocks are all lowercase keywords and produce no rows; the
  two menus and their four items were counted by reading.
