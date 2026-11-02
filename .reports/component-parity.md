# Component parity — raider-rb

| | |
|---|---|
| Upstream | `main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `fe65d4fc528569b77548e6cf8bb744135603ce5b` |
| Units with parity | **0 / 8** |
| Driven | yes — `xvfb-run bundle exec ruby` against the live widget tree, 42 + 16 + 6 read-back checks |
| Screenshots | none (see **Checks not run**) |

Eight units: application, window (incl. the two menu models), exit dialog,
shortcuts dialog, file row, progress popover, progress paintable, and the
`data/` + `po/` trees that no `lib/` file answers.

## Unit: application — `src/main.c` + `src/raider-application.c` → `lib/main.rb`

| Widget / thing | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk::Application` (`AdwApplication` up) | 1 | 1 | — | ✓ `activate`, `open` | — | parity (type swap explained: `Adwaita::Application` is unusable in the bindings) |
| `Adw.AboutDialog` | 1 | 1 | — | ✓ | ✗ | **gap** ×3, below |
| `Gio::SimpleAction` | 7 | 7 | — | ✓ `activate` ×7 | ✗ | parity on wiring |
| `Gtk::FileDialog` | 2 | 2 | — | ✓ | ✗ | parity on wiring |

- **gap** — About dialog's `application-icon` is `com.github.ADBeveridge.Raider`
  upstream (`src/raider-application.c:171`); the port sets
  `'edit-delete-symbolic'` (`lib/main.rb:40`, `:101`). Read back live:
  `about_dialog.application_icon == "edit-delete-symbolic"`.
- **gap** — `translator-credits` is set upstream
  (`src/raider-application.c:180`) and is unset in the port. Read back live:
  `about_dialog.translator_credits == ""`. The About dialog has no Translators
  page at all, and the msgid is lost with it.
- **gap** — version. `PACKAGE_VERSION` is `3.1.0` (`meson.build:1`); the port
  hardcodes `VERSION = '0.1.0'` (`lib/main.rb:38`), so the About dialog says
  0.1.0 and `--version` prints `File Shredder - 0.1.0` instead of
  `File Shredder - 3.1.0`. Driven: the string was printed.
- Accelerators: ✓ all seven match, read off the live application.
- Messages: 3 upstream in this file (`Add Files`, `Add Folders`,
  `translator-credits`), 2 present as unmarked literals, 1 absent. **gap**,
  tracked in `.reports/translation-parity.md`.
- Driven: 7 actions present; `--version` printed; About dialog constructed.

## Unit: window — `src/raider-window.blp` + `src/raider-window.c` → `lib/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | ✓ `close-request` | ✓ | **gap**: `icon-name` |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.Revealer` | 3 | 3 | — | — | — | parity |
| `Adw.SplitButton` | 1 | 1 | — | ✓ `action-name app.open` | ✓ | parity |
| `Adw.ButtonContent` | 1 | 1 | — | — | ✗ | unmarked |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✗ | unmarked |
| `Gtk.MenuButton` | 1 | 1 | — | — | ✗ | unmarked |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 3 | 3 | — | — | — | **gap**: `contents_box` orientation |
| `Gtk.DropTarget` | 1 | 1 | — | ✓ `drop` (**unverified**) | — | wiring present, not driven |
| `Gtk.Stack` | 1 | 1 | — | — | — | parity |
| `Adw.StatusPage` | 1 | 1 | — | — | ✗ | **gap**: `icon-name` |
| `Gtk.Overlay` | 1 | 1 | — | — | — | parity |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` | 1 | 1 | — | — | — | parity |
| `Gtk.ListBox` | 1 | 1 | ✓ `boxed-list` | — | — | parity |
| `Gtk.Button` ×3 | 3 | 3 | ✓ `pill`, `destructive-action` | ✓ `clicked` ×3 | ✗ | **gap**: two labels never render |
| menu models (`GMenu`) | 2 + 3 sections | 2 + 3 sections | — | — | ✗ | parity on structure |

Gaps, each with both sides located:

1. **The window icon is wrong.** Upstream `src/raider-window.blp:11`:
   `icon-name: "com.github.ADBeveridge.Raider"`. Port `lib/window.rb:23`,
   `:241`: `'edit-delete-symbolic'`. Read back live:
   `win.window.icon_name == "edit-delete-symbolic"`.
2. **The empty state shows the wrong icon.** Upstream `window.blp:58`:
   the app icon, a 128px illustration. Port `lib/window.rb:346`: the same
   16px symbolic delete glyph. Read back live. The app's whole first screen is
   a monochrome trash glyph instead of the Raider artwork, and it is the same
   glyph the row's remove button uses.
   Root cause for 1, 2 and the About icon: **`data/icons/` was never ported**,
   so there is no `com.github.ADBeveridge.Raider` icon in any theme and no
   installed `.desktop` to point at one. See the `data/` unit below.
3. **`"Starting Shredding…"` never appears.** Upstream
   `src/raider-window.c:411` sets it, then launches the per-row shredding in a
   `GTask` (`:415`) and only restores the labels in
   `raider_window_shred_files_finish` (`:387-388`). The port sets the label at
   `lib/window.rb:201` and overwrites it at `:211` in the same main-loop turn,
   with no yield between. Driven: `win.start_shredding;
   win.shred_button.label` → `"Shred All"`. The transient state the user is
   supposed to see is unreachable.
4. **`"Aborting…"` never appears either, and the window freezes instead.**
   Upstream `raider_window_abort_shredding` (`:457`) sets the label and runs
   the aborts in a `GTask`. The port sets it at `lib/window.rb:222`, then calls
   `FileRow#shredding_abort` for every row, each of which does
   `@corrupt&.wait` → `Thread#join` (`lib/corrupt.rb:70`) on the **main
   thread**, then restores the label at `:472`. Driven:
   `win.abort_shredding(exiting: false); win.abort_button.label` →
   `"Abort All"`. Aborting a large file blocks the main loop, so the app stops
   repainting rather than showing "Aborting…".
5. **The quick-list integrity error is gone.** Upstream
   `raider_window_close_file` searches `window->filenames` and, if the row's
   filename was not in it, calls
   `g_error(_("Could not remove filename from quick list. Please report this."))`
   — `g_error` aborts the process (`src/raider-window.c:228-229`). The port's
   `Window#close_file` (`lib/window.rb:160`) is `@rows.delete(row)` with no
   check. Driven: closing a row the window never held returns quietly. One
   upstream error state and one msgid, both absent.
6. **`contents_box` orientation.** Upstream `Gtk.Box contents_box` declares no
   orientation, so it is horizontal (`window.blp:49`); the port builds
   `Gtk::Box.new(:vertical, 0)` (`lib/window.rb:331`). With one child the
   rendering is the same today, which is exactly why it will bite whoever adds
   the second child.

Stylesheet: upstream ships no custom CSS; `boxed-list`, `pill` and
`destructive-action` are Adwaita's. Port classes match on every window widget.
✓ for this unit.

Messages: 15 upstream in this unit (13 in the shipped `.pot`, plus `Clear` and
`Clear All` which upstream's `.pot` has gone stale on), 14 present in the port
as bare literals, 1 (`Could not remove filename…`) absent. 0 marked. **gap**.

Driven: 3 rows → `list_page` ✓; `shred_revealer` revealed ✓; `clear_files`
→ 0 rows and `empty_page` ✓; a real two-file shred run → both files gone from
disk ✓, both rows gone ✓, `empty_page` ✓, `shredding?` false ✓,
`open_revealer` restored ✓, finish notification dispatched ✓ (it went out as a
desktop notification — correct, the headless window is not active); duplicate
add ✓, missing path ✓, unwritable path ✓, `request_exit` while idle → `false`
✓. `drop` ✗ — not driven, see **Checks not run**.

## Unit: exit dialog — `raider_window_exit` → `lib/exit_dialog.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.AlertDialog` | 1 | 1 | — | ✓ `response` | ✗ | parity but unmarked |
| responses | 2 | 2 | ✓ `exit` destructive | ✓ | ✗ | parity but unmarked |

Driven: heading `"Stop Shredding?"` ✓, `cancel` default + close ✓, `exit`
destructive ✓, `exit` → `abort_shredding(exiting: true)` → `window.destroy` ✓
by inspection. Messages: 4, all bare literals including the mnemonics
`_Cancel` / `_Exit`. **gap** on the text axis only.

## Unit: shortcuts dialog — `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | — | — | ✗ | **gap**: extra title |
| `Adw.ShortcutsSection` | 1 | 1 | — | — | ✗ | unmarked |
| `Adw.ShortcutsItem` | 5 | 5 | — | — | ✗ | **gap**: `action-name` dropped |

- **gap** — every upstream item is declared with `action-name` (`app.open`,
  `app.new-window`, `app.shortcuts`, `app.close`, `app.quit`), which makes GTK
  resolve and re-render the accelerator whenever the user rebinds it. The port
  hardcodes the five accelerator strings (`lib/shortcuts_dialog.rb:15-19`). The
  dialog now shows what `lib/main.rb` bound at the time this file was written,
  not what the application is actually bound to; the two are only in step
  because one file was copied from the other.
- **gap** — the port sets `self.title = 'Keyboard Shortcuts'`
  (`lib/shortcuts_dialog.rb:25`). Upstream sets no title on the dialog; the one
  it displays comes from libadwaita's own translated default. The port's title
  is an extra English-only string shadowing a translated one.
- Driven: dialog builds, title reads back, 1 section, 5 items.

## Unit: file row — `src/raider-file-row.blp` + `.c` → `lib/file_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ActionRow` | 1 | 1 | — | — | ✓ | parity |
| `Gtk.Box` `controls` | 1 | 1 | — | — | — | parity |
| `Gtk.Revealer` | 2 | 2 | — | — | — | parity |
| `Gtk.Button` `remove_button` | 1 | 1 | **✗ extra `flat`** | ✓ `clicked` | **✗ extra tooltip** | **gap** |
| `Gtk.Button` `progress_button` | 1 | 0 | **✗ extra `flat`** | ✓ (via `MenuButton`) | **✗ extra tooltip** | **gap** |
| `Gtk.MenuButton` | 0 | 1 | — | — | — | extra, explained |
| `Gtk.Image` (from paintable) | 1 | 1 | — | — | — | parity by substitution |
| popover | 1 | 1 | — | — | — | parity |

- **gap** — `flat` on both row buttons (`lib/file_row.rb:123`, `:139`).
  Upstream's `raider-file-row.blp` puts no `styles` on either. A flat button and
  a raised button are not the same control: upstream's delete button reads as a
  button in the row, the port's reads as an icon. Read back live:
  `remove_button.css_classes == ["flat", "image-button"]`.
- **gap** — two tooltips the port invented: `'Remove'` (`:122`) and
  `'Shredding Progress'` (`:136`). Upstream has neither. Both are English-only
  strings in an app with 34 catalogues; see `## Extra` in
  `.reports/translation-parity.md`.
- `Gtk::MenuButton` for `progress_button` is an **explained extra**: upstream
  parents a bare `GtkPopover` with `gtk_widget_set_parent` and pops it up from
  `clicked` (`src/raider-file-row.c:60-61`). The user-visible behaviour — click
  the progress icon, the popover opens — is reached. Driven by construction;
  the popup itself was not clicked.
- Not ported: upstream's `raider_file_row_set_progress_value` uses
  `g_mutex_trylock` to **drop** progress updates that arrive while one is being
  consumed (`src/raider-file-row.c:171-172`). The port pushes every tick
  through `GLib::Idle.add` (`lib/file_row.rb:162`), so a 100MB file queues one
  idle callback per completed pass per row with no coalescing. Behaviourally
  the same picture, a different load; recorded so it is not mistaken for parity.
- Driven: builds ✓, title/subtitle ✓, revealers swap on `launch_shredding` ✓
  (by inspection and by the end-to-end run), `close` removes the row ✓.

## Unit: progress popover — `src/raider-progress-info-popover.*` → `lib/progress_info_popover.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.Popover` | 1 | 1 | — | — | — | parity |
| `Gtk.Box` | 1 | 1 | — | — | — | parity |
| `Gtk.ProgressBar` | 1 | 1 | — | — | ✗ | parity but unmarked |

Driven, all four states: `0.0 → "Starting…"` + fraction 1 ✓, `0.42 → "42%"` ✓,
`1.0 → "Finishing up…"` + pulse ✓, `pulse → "Estimating…"` ✓. `pulse_step
0.02` ✓. This is the one unit whose behaviour is fully confirmed; it fails only
the text axis.

One robustness note, found while driving: `#build` is not idempotent — calling
it twice raises
`Gtk-CRITICAL gtk_box_append: assertion 'gtk_widget_get_parent (child) == NULL' failed`
at `lib/progress_info_popover.rb:28`. Nothing in the port calls it twice today.

## Unit: progress paintable — `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`

| Thing | Up × | Port × | Verdict |
|---|---:|---:|---|
| `GdkPaintable` + `GtkSymbolicPaintable` impl | 1 | 0 | substituted: `Gtk::Overlay` + `Gtk::DrawingArea` + `Gtk::Image` |
| `notify::scale-factor` → re-cache + `invalidate_size` | 1 | 0 | **gap** |
| arc geometry | radius `width/2 + 1` | radius `SIZE/2 - LINE_WIDTH/2` = 7 | **gap** |
| check-icon cross-fade | never runs | runs | **extra** |

- **gap** — upstream reconnects its icon cache and invalidates its size on
  `notify::scale-factor` (`src/raider-progress-paintable.c:78-80`) and reports
  `SIZE * scale_factor` as its intrinsic size (`:216`, `:224`). The port's
  `Gtk::DrawingArea` is pinned to `content_width/height = 16`
  (`lib/progress_paintable.rb:69-70`) with no scale handling, so the indicator
  does not follow a HiDPI or a mid-session scale change.
- **gap** — upstream strokes at radius `width / 2.0 + 1`, i.e. **outside** the
  16px box, with cairo's default 2.0 line width
  (`src/raider-progress-paintable.c:275`, `:280`). The port strokes at radius 7
  (`lib/progress_paintable.rb:136`). The ring is visibly smaller than
  upstream's and is clipped differently against the button edge.
- **extra, and it is not upstream's behaviour** — the port fades the arc out
  into an `object-select-symbolic` check icon over 400ms
  (`lib/progress_paintable.rb:84-91`, `:58-62`). Upstream never sets
  `icon-name`, so `cache_icons` returns early (`:52-55`), `check_paintable`
  stays `NULL`, and nothing ever writes `check_progress` — both branches that
  would scale it are dead. Upstream's indicator shows the arc and only the arc.
  `.reports/component-inventory.md` describes the cross-fade as upstream
  behaviour; it is not.
- Driven: builds and draws without error under software GL. The drawing itself
  was not compared against a screenshot.

## Unit: `data/` and `po/` — no port file

| Upstream file | Port | Verdict |
|---|---|---|
| `data/com.github.ADBeveridge.Raider.desktop.in.in` | — | **gap** |
| `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in` | — | **gap** |
| `data/com.github.ADBeveridge.Raider.service.in` | — | **gap** |
| `data/icons/.../Raider.svg`, `Raider.Devel.svg`, `Raider-symbolic.svg` | — | **gap** |
| `po/` (35 `.po`, `LINGUAS`, `POTFILES`, `.pot`) | — | **gap** |

What each absence costs the user:

- No desktop entry: the app does not appear in the launcher, has no name, no
  `Comment`, no `Keywords=delete;remove;permanently;files;shred;data;`, no
  `Categories`, and no icon. `X-GNOME-UsesNotifications=true` is gone, which is
  the declaration behind the finish notification the port does send.
- No metainfo: no Software listing, no summary, no description, no screenshot,
  no release notes.
- No D-Bus service file: `DBusActivatable=true` upstream, started via
  `raider --gapplication-service`. The port cannot be D-Bus activated, so a
  notification click or a file-manager "Open with" cannot start it.
- No icons: the cause of all three wrong-icon gaps above.
- No `po/`: see `.reports/translation-parity.md`. 0 of 35 messages, 0 of 34
  languages.

## Extra in the port, explained or not

| Extra | Explained? |
|---|---|
| `Gtk::MenuButton` for `progress_button` | yes — binding has no popover `set_parent` |
| `Gtk::Overlay`/`DrawingArea`/`Image` for the paintable | yes — no GObject interface implementation from Ruby |
| `flat` on two row buttons | **no** — remove it |
| tooltips `'Remove'`, `'Shredding Progress'` | **no** — remove them |
| check-icon cross-fade + `GLib::Timeout` | **no** — upstream's never runs |
| `Raider::Application` (`lib/raider/application.rb`), app id `org.rubygtkproject.Raider`, status page "The Ruby port has not been written yet." | **no** — dead scaffold, still required by `lib/raider.rb:3` and shipped in `spec.files` |
| `ShortcutsDialog` title `'Keyboard Shortcuts'` | **no** — shadows libadwaita's translated default |

## Checks not run

Named here rather than counted as passes:

- **Drag and drop.** `Gdk::FileList` has no constructor in gtk4 4.3.9
  (`undefined method 'new_from_array'`), so `Window#on_drop` was never fired.
  The whole drop path — the one way upstream's empty state tells the user to
  add files — is unverified.
- **Rendering.** No screenshots. GTK only initialises here under `xvfb-run`
  with software GL, so `flat` vs raised, the arc radius, the status-page icon
  size and the pill placement were read back as properties, not seen.
- **`app.quit` across two windows.** `App#action_quit` was not driven with a
  second window mid-shred.
- **The popover popup.** `progress_button` was never clicked, so "click the
  progress icon, see the percentage" is confirmed only by construction.

## Verdict

0 of 8 units has parity. The widget tree, the action map and the accelerators
are close to right; the icons, the two transient button labels, one error state,
the shortcut-action bindings, the paintable geometry and scale handling, every
message, and the whole of `data/` and `po/` are not.
