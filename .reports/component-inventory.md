# Raider (File Shredder) — upstream component inventory

Upstream: `origin/main`, C + GTK4 + libadwaita + blueprint, app id
`com.github.ADBeveridge.Raider`, 7 `.c` files and 4 `.blp` files under `src/`.
Port: the `ruby` branch, 3 `.rb` files — `lib/raider.rb`,
`lib/raider/application.rb` (the generated skeleton: a blank Adwaita window
with a "port has not been written yet" status page) and
`lib/raider/rb/version.rb`. **No user-facing component is ported yet.**

The app: add files or folders (button, menu, `--`/`open` handler, or drag and
drop), see them as a boxed list of rows, shred them all with a multi-pass
overwrite, watch per-file progress in a popover, abort mid-run, get a toast or
a desktop notification when done.

No GSettings schema exists upstream — the app keeps no settings and has no
preferences dialog. Translations: `po/` has 33 catalogues and a 36-message
`.pot`; every string in the inventory below is one of them.

## Upstream → port file map

| Upstream | Port target | Kind |
|---|---|---|
| `src/main.c` + `src/raider-application.c` | `lib/main.rb` | application class, actions, accels, About, CLI options |
| `src/raider-window.blp` + `src/raider-window.c` | `lib/window.rb` | main window |
| `src/raider-window.blp` (`primary_menu`, `open_menu`) | `lib/window.rb` | menu models |
| `src/raider-shortcuts.blp` | `lib/shortcuts_dialog.rb` | shortcuts dialog |
| `src/raider-file-row.blp` + `src/raider-file-row.c` | `lib/file_row.rb` | list row |
| `src/raider-progress-info-popover.blp` + `.c` | `lib/progress_info_popover.rb` | popover |
| `src/raider-progress-paintable.c` | `lib/progress_paintable.rb` | drawn paintable |
| `src/corrupt.c` | `lib/corrupt.rb` | shredding backend (no UI) |
| `src/raider-window.c` (`raider_window_exit`) | `lib/exit_dialog.rb` | alert dialog |

## src/main.c + src/raider-application.c — the application

| Component | × | Notes |
|---|---:|---|
| `Gtk.Application` (upstream `Adw.Application`, flags `HANDLES_OPEN`) | 1 | Ruby bindings: use `Gtk::Application`; `Adwaita::Application` is broken |
| `Adw.AboutDialog` (via `adw_show_about_dialog`) | 1 | name "File Shredder", icon, version, © 2024 Alan Beveridge, issue URL, GPL-3.0, developers/artists/designers lists, `translator-credits` |

Actions installed on `app`, with accelerators:

| Action | Accel | Does |
|---|---|---|
| `app.open` | `<Ctrl>o` | `Gtk.FileDialog`, modal, title _("Add Files"), `open_multiple` |
| `app.open-folder` | — | `Gtk.FileDialog`, title _("Add Folders"), `select_multiple_folders` |
| `app.new-window` | `<Ctrl>n` | new `RaiderWindow`, present |
| `app.close` | `<Ctrl>w` | close active window |
| `app.quit` | `<Ctrl>q` | asks every window via `raider_window_exit`; quits only if none is shredding |
| `app.about` | — | the About dialog above |
| `app.shortcuts` | — | **not installed in C** — GTK supplies it from the `shortcuts-dialog.ui` resource alias |
| `app.open-drive` | — | commented out upstream ("Flatpak removes access to device files"); do not port |

Also: `open` vfunc (files from the command line → new window + `open_files`),
`handle_local_options` for `--new-window`/`-w` and `--version`/`-v` (prints
"File Shredder - <version>"), and the `g_notification_new` desktop notification
sent from the window when shredding finishes while the window is inactive.

## src/raider-window.blp + src/raider-window.c — the main window

`Adw.ApplicationWindow`, 800×600, minimum 270×300, title _("File Shredder").

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | — | `close-request` → `raider_window_exit` | |
| `Adw.ToolbarView` | 1 | — | — | `vexpand` |
| `Adw.HeaderBar` | 1 | — | — | `centering-policy: strict` |
| `Gtk.Revealer` `open_revealer` | 1 | — | — | slide-right, revealed; hidden while shredding |
| `Adw.SplitButton` `open_button` | 1 | — | `action-name: app.open`, `menu-model: open_menu` | child is an `Adw.ButtonContent` |
| `Adw.ButtonContent` | 1 | — | — | label _("Add"), `document-open-symbolic`, tooltip _("Add Files") |
| `Adw.WindowTitle` | 1 | — | — | _("File Shredder") |
| `Gtk.MenuButton` | 1 | — | `menu-model: primary_menu` | `open-menu-symbolic`, tooltip _("Main Menu"), `primary` |
| `Adw.ToastOverlay` | 1 | — | — | host for every toast below |
| `Gtk.Box` `contents_box` | 1 | — | hosts the drop target | `margin-top: 24` |
| `Gtk.DropTarget` (controller) | 1 | — | `drop` → `on_drop` | `GDK_TYPE_FILE_LIST`, `ACTION_COPY`, added to `contents_box` |
| `Gtk.Stack` `window_stack` | 1 | — | — | crossfade; pages `empty_page`, `list_page` |
| `Adw.StatusPage` `empty_state` | 1 | — | — | title _("Add files or drop here"), app icon, description _("Shredding is the obfuscation of a file with random data so the previous contents cannot be recovered.") |
| `Gtk.Overlay` | 1 | — | — | scrolled list + two overlaid revealers |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `Adw.Clamp` | 1 | — | — | `maximum-size: 700` |
| `Gtk.ListBox` `list_box` | 1 | `boxed-list` | — | `valign: start`, 12px margins; desensitised while aborting |
| `Gtk.Revealer` `shred_revealer` | 1 | — | — | slide-up, bottom-centre, holds Clear + Shred All |
| `Gtk.Button` `clear_button` | 1 | `pill` | `clicked` → `raider_window_clear_files` | label _("Clear"), relabelled _("Clear All") after a run |
| `Gtk.Button` `shred_button` | 1 | `destructive-action`, `pill` | `clicked` → `raider_window_start_shredding` | label _("Shred All"), becomes _("Starting Shredding…") while starting |
| `Gtk.Revealer` `abort_revealer` | 1 | — | — | slide-up, bottom-centre |
| `Gtk.Button` `abort_button` | 1 | `destructive-action`, `pill` | `clicked` → `raider_window_abort_shredding` | label _("Abort All"), becomes _("Aborting…") |

Repeater: one `RaiderFileRow` per accepted file, appended to `list_box`.
States: `empty_page` when `file_count == 0`, `list_page` otherwise;
open-revealer visible unless shredding; shred-revealer and abort-revealer
mutually exclusive.

Toasts (all via `Adw.Toast` on the overlay), each a translated string:

- _("This file was already added") — duplicate path
- _("Some files did not exist") — `g_file_query_exists` false
- _("Cannot write to “%s”") — no `W_OK`
- _("Cannot load more files") — `file_count >= RLIMIT_NOFILE / 2`; stops the batch
- _("Finished shredding files") — toast if the window is active, `GNotification` if not

### Menu models (same file)

`primary_menu` — section 1: _("New Window") → `app.new-window`; section 2:
_("Keyboard Shortcuts") → `app.shortcuts`, _("About File Shredder") →
`app.about`. `open_menu` — _("Open Folder") → `app.open-folder`.

### The exit dialog (`raider_window_exit`)

`Adw.AlertDialog`, heading _("Stop Shredding?"), body _("Are you sure that you
want to exit?"), responses `cancel` _("_Cancel") and `exit` _("_Exit") with
`exit` destructive, default and close response `cancel`; `response` → abort
everything then destroy. Shown only while `status` is true, i.e. a run is in
flight; it is also what makes `app.quit` conditional.

## src/raider-file-row.blp + src/raider-file-row.c — one file in the list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` (template root) | 1 | — | — | not selectable, activatable, `use-markup: false`; title = basename, subtitle = full path; activatable widget switched to `progress_button` while shredding |
| `Gtk.Box` `controls` | 1 | — | — | `valign: center`, row suffix |
| `Gtk.Revealer` `remove_revealer` | 1 | — | — | slide-left, revealed by default |
| `Gtk.Button` `remove_button` | 1 | — | `clicked` → `raider_file_row_close` | `edit-delete-symbolic` |
| `Gtk.Revealer` `progress_revealer` | 1 | — | — | slide-left, hidden by default |
| `Gtk.Button` `progress_button` | 1 | — | `clicked` → pops up the popover | child is a `Gtk.Image` of the progress paintable |
| `Gtk.Image` | 1 | — | — | built in C from the paintable, not in the `.blp` |
| `RaiderProgressInfoPopover` | 1 | — | — | parented to `progress_button` |

Behaviour: `launch_shredding` swaps remove→progress and starts `Corrupt`;
`shredding_abort` swaps back and cancels; a clean finish removes the row and
arms the finish notification; removing a row decrements the window's count and
can flip the stack back to the empty page.

## src/raider-progress-info-popover.blp + .c — the progress popover

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` (template root) | 1 | — | — | |
| `Gtk.Box` `popover_box` | 1 | — | — | |
| `Gtk.ProgressBar` `progress_bar` | 1 | — | — | `show-text`, `hexpand`, pulse step `.02` |

Text states: _("Starting…") at 0%, `"<n>%"` below 100%, _("Finishing up…")
pulsing at 100%, _("Estimating…") from `pulse()`.

## src/raider-progress-paintable.c — the progress icon

A `GObject` implementing `GdkPaintable` and `GtkSymbolicPaintable`, 16px,
properties `icon-name`, `widget`, `progress`; draws a pie-style progress arc
and cross-fades to a cached check icon, invalidating on
`notify::scale-factor`. Not a widget — it is what `progress_button` shows.
Ported from Purism's original.

## src/corrupt.c — the shredding backend (no UI)

`RaiderCorrupt`: 5 overwrite passes with the fixed 3-byte patterns
`www`/`vvv`/`333`/`555`/`UUU`, then unlink; recurses into folders; reports
progress through `file_row_set_progress_value` + a main-context invoke of
`update_progress_ui`; cancellable via `GCancellable`, polled each write. One
translated string: _("Could not remove filename from quick list. Please report
this.") (actually emitted from the window).

## Not components

`data/*.desktop.in.in`, `data/*.metainfo.xml.in.in`, `data/*.service.in`,
icons, `meson.build`, `subprojects/*.wrap`, `com.github...Raider.json`
(Flatpak manifest), `src/README.md`, `raider.doap`.

## Blockers and notes for the port

- `Adwaita::Application` is broken in the Ruby bindings — the port must use `Gtk::Application` with `Adwaita::ApplicationWindow`, as the skeleton already does.
- `app.shortcuts` is free in C because GTK loads the `shortcuts-dialog.ui` GResource alias. The port has no GResource, so it must install the action itself and present an `Adwaita::ShortcutsDialog` built in Ruby (`lib/shortcuts_dialog.rb`).
- `RLIMIT_NOFILE / 2` as the file cap: reachable in Ruby via `Process.getrlimit(:NOFILE)`.
- The whole app is threaded (`GTask` for opening, shredding and aborting, with mutexes per row). The port should drive these from the main loop instead — shred in a thread and marshal UI updates through `GLib::Idle.add` — because GTK widgets may only be touched on the main thread.
- `raider-progress-paintable.c` needs a custom `GdkPaintable` implementation; Ruby-GNOME cannot subclass and implement `Gdk::Paintable`/`Gtk::SymbolicPaintable` reliably. Substitute a `Gtk::DrawingArea` (or a `Gtk::ProgressBar`-backed button child) drawn with Cairo and note the divergence.
- `--version` / `--new-window` local option handling and the `open` vfunc (`HANDLES_OPEN`) have no direct Ruby binding for `handle_local_options`; handle `ARGV` in the launcher and connect the `open` signal instead.
- `GUnixMountEntry` device shredding is commented out upstream; it is not part of the parity surface.
- 33 `po/` catalogues and 36 messages: translation parity is a separate step, but every user-visible string above is translatable upstream.
