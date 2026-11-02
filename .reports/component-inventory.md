# Raider (File Shredder) — upstream component inventory

Upstream: `origin/main`, C + GTK4 + libadwaita + blueprint, app id
`com.github.ADBeveridge.Raider`, 7 `.c` files and 4 `.blp` files under `src/`.
Port: the `ruby` branch — `lib/` holds one file per upstream source, plus
`lib/package_config.rb` for `meson.build`'s `config_h`, `lib/translation.rb`
for the gettext setup in `src/main.c`, and `lib/data_files.rb` for
`data/meson.build`'s merge steps. `data/` and `po/` are upstream's.

The app: add files or folders (button, menu, `--`/`open` handler, or drag and
drop), see them as a boxed list of rows, shred them all with a multi-pass
overwrite, watch per-file progress in a popover, abort mid-run, get a toast or
a desktop notification when done.

No GSettings schema exists upstream — the app keeps no settings and has no
preferences dialog. Translations: `po/LINGUAS` lists **34** languages and the
directory holds **35** `.po` files, because `pl.po` is on disk and unlisted, so
upstream does not ship it. The shipped `.pot` carries **35** msgids and is
stale: it misses `Clear` (`src/raider-window.blp:95`) and `Clear All`
(`src/raider-window.c:349`), and it spells `Estimating...` where the source
says `Estimating…`. The real message set is **37**.

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
properties `icon-name`, `widget`, `progress`; draws a progress arc at radius
`width / 2 + 1` with Cairo's default 2px line, and re-caches and invalidates
its size on `notify::scale-factor`. Not a widget — it is what `progress_button`
shows. Ported from Purism's original.

Its `snapshot_symbolic` also holds a cross-fade to a cached check icon, and
that code never runs: no caller sets `icon-name`, so `cache_icons` returns
early, and nothing ever writes `check_progress`, so it stays 0. **The
cross-fade is not upstream behaviour and must not be ported.**

## src/corrupt.c — the shredding backend (no UI)

`RaiderCorrupt`: 5 overwrite passes with the fixed 3-byte patterns
`www`/`vvv`/`333`/`555`/`UUU`, then unlink; recurses into folders; reports
progress through `file_row_set_progress_value` + a main-context invoke of
`update_progress_ui`; cancellable via `GCancellable`, polled each write. One
translated string: _("Could not remove filename from quick list. Please report
this.") (actually emitted from the window).

## data/, po/ and the build — also components

An earlier revision of this ledger filed these under "not components" and
added a section telling the next agent which features it could skip. Both were
wrong. They are listed here as components, with the behaviour each one carries:

| Upstream | Port target | Carries |
|---|---:|---|
| `data/com.github.ADBeveridge.Raider.desktop.in.in` | `data/…desktop.in.in` | the launcher entry; `DBusActivatable=true`; msgids `File Shredder`, `Permanently delete your files` |
| `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in` | `data/…metainfo.xml.in.in` | the Software listing; msgids `File Shredder`, `Permanently delete your files` and two description paragraphs |
| `data/com.github.ADBeveridge.Raider.service.in` | `data/…service.in` | D-Bus activation, `raider --gapplication-service` |
| `data/icons/hicolor/{scalable,symbolic}/apps/*.svg` | `data/icons/…` | the window icon, the empty-state illustration and the About dialog's icon |
| `data/meson.build` (the two `i18n.merge_file` calls) | `lib/data_files.rb` | `msgfmt --desktop` and `msgfmt --xml`, which is how `Name[xx]` and `xml:lang` reach the installed files |
| `po/` + `po/meson.build` | `po/`, `lib/translation.rb`, `rake gettext:mo` | 34 catalogues under the domain `raider` |
| `meson.build` `config_h` | `lib/package_config.rb` | `PACKAGE_VERSION` 3.1.0, `GETTEXT_PACKAGE`, `LOCALEDIR` |

Genuinely not components: `subprojects/*.wrap`, `com.github...Raider.json`
(the Flatpak manifest), `src/README.md`, `raider.doap`,
`data/raider-screenshot1.png`.

## Upstream's tests

`data/meson.build` defines two, and both must be ported:

| Upstream | What it runs |
|---|---|
| `data/meson.build:12` `'Validate desktop file'` | `desktop-file-validate` on the **merged** `.desktop` |
| `data/meson.build:27` `'Validate appstream file'` | `appstreamcli validate --no-net` on the **merged** metainfo |

Each is guarded by `find_program(…, required: false)`, so upstream skips it
when the validator is not installed. There are no other tests upstream.

## Notes on upstream's mechanisms

Facts about the upstream source, for whoever ports the next piece. None of
these is permission to leave anything out.

- `app.shortcuts` is free in C because GTK loads the `shortcuts-dialog.ui`
  GResource alias; it has to be installed by hand wherever there is no
  resource bundle.
- The file cap is `RLIMIT_NOFILE / 2` (`src/raider-window.c:315`).
- Opening, shredding and aborting each run in a `GTask`, and the two transient
  button labels (`Starting Shredding…`, `Aborting…`) exist only because the
  work is off the main loop and the labels are restored in the finish
  callback. A port that runs them synchronously deletes two strings from the
  UI and freezes the window; see `lib/window.rb`.
- `--version` / `--new-window` are handled in `handle_local_options`, which
  returns -1 for anything else so that GApplication still sees it — that is
  how `--gapplication-service` reaches D-Bus activation.
- `GUnixMountEntry` device shredding and `app.open-drive` are commented out in
  upstream's own source (`src/raider-application.c:125-140`,
  `src/raider-window.c:482-509`), so they are not shipped behaviour.
