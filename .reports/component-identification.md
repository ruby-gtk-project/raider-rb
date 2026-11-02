# Component identification — raider-rb, port side

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` (2026-05-13) |
| Port | `ruby` @ `fe65d4fc528569b77548e6cf8bb744135603ce5b` |
| Upstream units | 7 (application, window, menus, shortcuts dialog, file row, popover, paintable) + 1 non-UI backend |
| Port files | 9 under `lib/`, 1 under `exe/` |

The upstream-side inventory is `.reports/component-inventory.md` (committed in
`f8ecee6`). This document is the **port** side of Step 1, plus the corrections
the upstream inventory needs.

## Corrections to `.reports/component-inventory.md`

That document is the baseline every other ledger joins against, and three of
its numbers are wrong. They are wrong in the direction that makes the port look
closer to done, so they are fixed here before anything is compared.

| It says | Actually |
|---|---|
| "`po/` has 33 catalogues and a 36-message `.pot`" | 35 `.po` files, 34 of them listed in `LINGUAS` (`pl.po` exists and is **not** shipped), and the `.pot` carries **35** messages, not 36 — `grep -c '^msgid "'` counts the header entry |
| "No GSettings schema exists upstream" | True, and still true. Kept |
| "`src/raider-progress-paintable.c` … cross-fades to a cached check icon" | Upstream never sets `icon-name` and never writes `check_progress`, so `check_paintable` is always `NULL` and the cross-fade **never runs upstream**. The port's check-icon fade is an invention, not a port |
| Nothing is said about upstream's two meson `test()` targets | `data/meson.build:12` and `:27` define `Validate desktop file` and `Validate appstream file`. Upstream is **not** a zero-test project — see `.reports/test-parity.md` |

It also omits, entirely, the parts of upstream that are not `src/`: `data/`
(desktop entry, metainfo, D-Bus service, three icons) and `po/`. Those carry
four of the 35 msgids and both upstream tests, so leaving them in a "Not
components" list is how 6 of 35 messages and 2 of 2 tests disappear.

## Port file map, as built

| Port file | Upstream it answers | Top-level thing |
|---|---|---|
| `lib/main.rb` | `src/main.c` + `src/raider-application.c` | `App` — actions, accels, About, CLI |
| `lib/window.rb` | `src/raider-window.blp` + `src/raider-window.c` | `Window` + both `Gio::Menu` models |
| `lib/file_row.rb` | `src/raider-file-row.blp` + `.c` | `FileRow < Adwaita::ActionRow` |
| `lib/progress_info_popover.rb` | `src/raider-progress-info-popover.blp` + `.c` | `ProgressInfoPopover < Gtk::Popover` |
| `lib/progress_paintable.rb` | `src/raider-progress-paintable.c` | `ProgressPaintable` — a plain object, not a widget |
| `lib/shortcuts_dialog.rb` | `src/raider-shortcuts.blp` | `ShortcutsDialog < Adwaita::ShortcutsDialog` |
| `lib/exit_dialog.rb` | `raider_window_exit` in `src/raider-window.c` | `ExitDialog < Adwaita::AlertDialog` |
| `lib/corrupt.rb` | `src/corrupt.c` | `Corrupt` — no UI |
| `lib/raider.rb` | — | requires `raider/application` **and** `main` |
| `lib/raider/application.rb` | **nothing** | `Raider::Application` — the dead scaffold, still shipped |
| `exe/raider` | `src/main.c` | launcher |
| — | `data/*` (desktop, metainfo, service, 3 icons) | **no port file** |
| — | `po/*` (35 `.po`, `LINGUAS`, `POTFILES`) | **no port file** |

Two upstream trees map to nothing, and one port file maps to nothing upstream.

## lib/window.rb — the one window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adwaita::ApplicationWindow` | 1 | — | `close-request` → `request_exit` | `icon_name = 'edit-delete-symbolic'`, not the app icon |
| `Adwaita::ToolbarView` | 1 | — | — | `vexpand` |
| `Adwaita::HeaderBar` | 1 | — | — | `centering_policy = :strict` |
| `Gtk::Revealer` | 3 | — | — | `open_revealer` slide-right; `shred_revealer` / `abort_revealer` slide-up, `valign :end`, `halign :center`, `margin_bottom 20` |
| `Adwaita::SplitButton` | 1 | — | `action_name 'app.open'` | `menu_model = open_menu` |
| `Adwaita::ButtonContent` | 1 | — | — | 'Add' / `document-open-symbolic` / tooltip 'Add Files' |
| `Adwaita::WindowTitle` | 1 | — | — | `('File Shredder', '')` |
| `Gtk::MenuButton` | 1 | — | — | `open-menu-symbolic`, tooltip 'Main Menu', `primary` |
| `Adwaita::ToastOverlay` | 1 | — | — | host for 5 toast texts |
| `Gtk::Box` | 3 | — | — | `contents_box` (**`:vertical`**; upstream's is horizontal), `shred_box`, `abort_box` |
| `Gtk::DropTarget` (controller) | 1 | — | `drop` → `on_drop` | `Gdk::FileList.gtype`, `:copy`, on `contents_box` |
| `Gtk::Stack` | 1 | — | — | crossfade, `add_named` ×2 |
| `Adwaita::StatusPage` | 1 | — | — | title 'Add files or drop here', **icon `edit-delete-symbolic`** |
| `Gtk::Overlay` | 1 | — | — | scroller + 2 overlaid revealers |
| `Gtk::ScrolledWindow` | 1 | — | — | |
| `Adwaita::Clamp` | 1 | — | — | `maximum_size 700` |
| `Gtk::ListBox` | 1 | `boxed-list` | — | 12px margins, `valign :start` |
| `Gtk::Button` | 3 | `pill`; `destructive-action`+`pill` ×2 | `clicked` → `clear_files` / `start_shredding` / `abort_shredding` | labels 'Clear', 'Shred All', 'Abort All' |
| `Gio::Menu` | 5 | — | — | `primary_menu` + 2 sections, `open_menu` + 1 section |
| `Adwaita::Toast` | per message | — | — | 5 texts, all bare literals |

Repeater: one `FileRow` per accepted file, `@rows` array plus `list_box.append`.
States: `empty_page` when `@rows.empty?`, `list_page` otherwise. Driven and
confirmed: 3 rows → `list_page`, `clear_files` → 0 rows and `empty_page`.

## lib/file_row.rb — one file in the list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adwaita::ActionRow` (self) | 1 | — | — | title basename, subtitle path, `activatable`, `use_markup false` |
| `Gtk::Box` `controls` | 1 | — | — | `valign :center`, added via `add_suffix` |
| `Gtk::Revealer` | 2 | — | — | slide-left, remove revealed / progress hidden |
| `Gtk::Button` `remove_button` | 1 | **`flat`** (+ auto `image-button`) | `clicked` → `close` | `edit-delete-symbolic`, **tooltip 'Remove'** |
| `Gtk::MenuButton` `progress_button` | 1 | **`flat`** | — (menu button owns the popover) | **upstream is a `Gtk::Button`**, tooltip 'Shredding Progress' |
| `ProgressInfoPopover` | 1 | — | — | set as the menu button's popover |
| `Gtk::Overlay` + `Gtk::DrawingArea` + `Gtk::Image` | 1 each | — | `set_draw_func` | the paintable substitute, as the button's child |

## lib/progress_info_popover.rb

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::Popover` (self) | 1 | — | — | |
| `Gtk::Box` | 1 | — | — | horizontal |
| `Gtk::ProgressBar` | 1 | — | — | `show_text`, `hexpand`, `pulse_step 0.02` |

Driven: `0.0 → "Starting…"`, `0.42 → "42%"`, `1.0 → "Finishing up…"`,
`pulse → "Estimating…"`. All four states fire.

## lib/shortcuts_dialog.rb

| Widget | × | Notes |
|---|---:|---|
| `Adwaita::ShortcutsDialog` (self) | 1 | title 'Keyboard Shortcuts' |
| `Adwaita::ShortcutsSection` | 1 | 'General' |
| `Adwaita::ShortcutsItem` | 5 | **built with `(title, accelerator)`; upstream builds them with `action-name`** |

## lib/exit_dialog.rb

| Widget | × | Signals | Notes |
|---|---:|---|---|
| `Adwaita::AlertDialog` (self) | 1 | `response` → abort + destroy | heading 'Stop Shredding?', 2 responses, `exit` destructive, `cancel` default + close |

## lib/main.rb — the application

| Component | × | Notes |
|---|---:|---|
| `Gtk::Application` | 1 | `:handles_open`, id `com.github.ADBeveridge.Raider` |
| `Adwaita::AboutDialog` | 1 | **no `translator_credits`**, **`application_icon = 'edit-delete-symbolic'`**, **`version = '0.1.0'`** |
| `Gio::SimpleAction` | 7 | open, open-folder, new-window, close, quit, about, shortcuts |
| `Gtk::FileDialog` | 2 | 'Add Files' / `open_multiple`; 'Add Folders' / `select_multiple_folders` |

Accelerators, driven off the live application: `app.open <Control>o`,
`app.new-window <Control>n`, `app.close <Control>w`, `app.quit <Control>q`,
`app.shortcuts <Control>question`, `app.open-folder` and `app.about` none.
Matches upstream (`<Control>question` is GTK's own default for the action GTK
supplies upstream).

## lib/raider/application.rb — not a component of this app

`Raider::Application` is the generated scaffold: a second `Gtk::Application`
with the id `org.rubygtkproject.Raider`, a window titled `raider`, and an
`Adwaita::StatusPage` reading "The Ruby port has not been written yet." It
corresponds to no upstream file, and `lib/raider.rb` still requires it, so
`require 'raider'` defines it in every process that loads the port. Confirmed
live: `Raider::Application.new.app.application_id` → `"org.rubygtkproject.Raider"`.

## Opening survey

| Axis | Upstream distinct | Port distinct | In upstream, not in port |
|---|---:|---:|---:|
| Widget / object types | 27 | 25 | `Gtk::Button` (as the progress button), `GtkIconPaintable`, `GdkPaintable`/`GtkSymbolicPaintable` impl, `GtkImage` from a paintable |
| CSS classes | 3 (`boxed-list`, `pill`, `destructive-action`) | 4 | 0 missing, **1 extra** (`flat`, on two row buttons) |
| Signals connected | 5 (`close-request`, `drop`, `clicked`, `response`, `notify::scale-factor`) | 4 | `notify::scale-factor` |
| Actions | 7 | 7 | 0 |
| Marked messages | 37 in source (35 in the shipped `.pot`) | **0** | 37 |
| Data files | 6 (`.desktop`, metainfo, `.service`, 3 icons) | 0 | 6 |
| Catalogues | 35 `.po` / 34 shipped | 0 | 35 |

The widget and action rows read as nearly finished. The message row and the
data-file row are where this port actually is.

## Checks not run

- `on_drop` could not be driven: `Gdk::FileList` has no constructor in
  gtk4 4.3.9 (`NoMethodError: undefined method 'new_from_array'`), so drag and
  drop is confirmed only by reading `lib/window.rb:477`.
- No screenshots. GTK initialises in this environment only under `xvfb-run`
  with software GL (`libEGL warning: DRI3 error`); widget state was read back
  instead of rendered.
