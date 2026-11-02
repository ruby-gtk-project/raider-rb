# Porting status — raider-rb

Resume point for the next run. Factual only.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port branch | `ruby` (local only — never pushed, never merged with `origin/main`) |
| Parity units with parity | 5 / 9 |
| Open gaps from the last audit | 16 (clean = false) |
| Last recorded test run | 93 passed, 0 failed, 0 pending (`.rspec_status`); `bundle exec rspec` inside `nix develop` |

## Upstream

Raider ("File Shredder") lets you add files or folders by button, menu,
command line or drag-and-drop, lists them as a boxed list, then overwrites each
one with five fixed byte patterns and unlinks it, with per-file progress,
abort, toasts and a finish notification.

It is implemented in C — GTK4 plus libadwaita, UI in blueprint `.blp` files
compiled into a GResource, built with meson. The spec lives on the
`origin/main` ref of this repository; read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check that ref out and never merge it.

## Done

Implemented and believed complete at file granularity. "Believed complete" is
not "has parity" — the gaps below sit inside several of these files.

| Port | Upstream |
|---|---|
| `lib/main.rb` | `src/main.c`, `src/raider-application.c` |
| `lib/window.rb` | `src/raider-window.blp`, `src/raider-window.c` |
| `lib/file_row.rb` | `src/raider-file-row.blp`, `src/raider-file-row.c` |
| `lib/progress_info_popover.rb` | `src/raider-progress-info-popover.blp`, `src/raider-progress-info-popover.c` |
| `lib/progress_paintable.rb` | `src/raider-progress-paintable.c` (substituted — see Blockers) |
| `lib/corrupt.rb` | `src/corrupt.c`, `src/corrupt.h` |
| `lib/shortcuts_dialog.rb` | `src/raider-shortcuts.blp` (built in Ruby — see Blockers) |
| `lib/exit_dialog.rb` | the `raider_window_exit` alert dialog in `src/raider-window.c` |
| `lib/package_config.rb` | the `config_h` block in `meson.build` (`PACKAGE_VERSION`, `GETTEXT_PACKAGE`, `LOCALEDIR`) |
| `lib/translation.rb` | the gettext setup in `src/main.c` |
| `lib/data_files.rb` | `data/meson.build`, `data/icons/meson.build`, `po/meson.build` |
| `data/`, `po/` | upstream `data/` templates and icons, 35 `.po` plus the `.pot`; 34 `.mo` built by `Rakefile:193-232` |

`src/meson.build`, `src/raider.gresource.xml` and the top-level `meson.build`
have no single Ruby counterpart by design: the gem's `Rakefile`, `flake.nix`
and `lib/data_files.rb` carry their work between them.

## Not started

No upstream source file is without a Ruby counterpart. Two upstream artefacts
have none:

- `data/raider-screenshot1.png` — not copied across (gap C9).
- `GOptionEntry` command-line declaration (`src/raider-application.c:252-260`)
  — the port scans `ARGV` instead and declares nothing (gap C1).

## Open gaps

16 open, from `.reports/` (audited against `ruby` @ `6a8dd32`; clean = false).
Nine component gaps, two translation gaps, five accountability items.

Component — `.reports/component-parity.md`:

- **C1** `--help` lists neither `--version` nor `--new-window`; `lib/main.rb:134-147`
  matches four literal spellings off `ARGV`, so a misspelling is taken as a filename.
- **C2** `lib/window.rb:342` builds `contents_box` as `:vertical`;
  `src/raider-window.blp:50` sets no orientation, so upstream is horizontal.
  Invisible with one child. Flagged by a previous review and not fixed.
- **C3** file loading is synchronous (`lib/window.rb:137-145`); upstream wraps
  the open loop in `g_task_run_in_thread` (`src/raider-window.c:286-292`), so a
  large drop freezes the port's window.
- **C4** the file dialog resolves `app.active_window` at completion
  (`lib/main.rb:235-257`) instead of capturing the window before presenting it
  (`src/raider-application.c:79-84`); with two windows open the files can land
  in the wrong one.
- **C5** `lib/corrupt.rb:242-246` swallows the "failed to open directory for
  removal" diagnostic (`src/corrupt.c:219-224`) and reports the wrong reason.
- **C6** `lib/file_row.rb:132`, `:145`, `:146` set `valign` on both buttons and
  `always_show_arrow = false`; upstream sets none of the three.
- **C7** the running app has never been looked at. Both visible substitutions
  (`Gtk::MenuButton` for the progress button, `Gtk::DrawingArea` for the
  paintable) were argued on paper only. No screenshots.
- **C8** the AppStream developer id was retyped as `io.github.adbeveridge`;
  upstream's `data/…metainfo.xml.in.in:24` reads `io.github.ADBeveridge`.
- **C9** `data/raider-screenshot1.png` absent, so the port's AppStream entry
  points at a file only upstream's tree holds.

Translation — `.reports/translation-parity.md` (38/38 msgids byte-identical;
these two are the open items):

- **T1** `po/pl.po` exists but `po/LINGUAS` omits `pl`, so 34 of 35 catalogues
  are built and a Polish user gets English. Upstream has the same hole;
  `spec/translation_spec.rb:57` currently asserts the hole as expected
  behaviour and must be inverted.
- **T2** `po/com.github.ADBeveridge.Raider.pot` is upstream's build artefact
  verbatim: every `#:` reference names a C or `.blp` file that does not exist
  in this repository, and it is stale against the 38 source keys.

Accountability — `.reports/accountability-ensurance.md`, five comment/test
rewrites still owed (A1 `spec/support/gtk.rb:11`, A2
`spec/translation_spec.rb:57`, A3 `lib/progress_paintable.rb:28-30`, A4
`lib/shortcuts_dialog.rb:15-16`, A5 `lib/translation.rb:20-22`). A5 also owes
an encoding assertion, since the port makes no
`bind_textdomain_codeset` equivalent call.

## Blockers

Recorded divergences. Each is a binding or platform limit, not a deferral.

- **`Adwaita::Application` is broken in the Ruby bindings.** The port uses
  `Gtk::Application` with `Adwaita::ApplicationWindow` and an explicit
  `Adwaita.init` (`lib/main.rb:92-94`).
- **`src/raider-progress-paintable.c` cannot be ported literally.** It is a
  GObject implementing `GdkPaintable` and `GtkSymbolicPaintable`; Ruby-GNOME
  cannot reliably subclass GObject and implement those interfaces. Substituted
  with a `Gtk::DrawingArea` drawn in Cairo inside `progress_button`. Upstream's
  symbolic colours are approximated by reading `style_context.color` at draw
  time, which is the unverified half of gap C7.
- **`app.shortcuts` is never installed in C** — GTK synthesises it from the
  GResource alias `shortcuts-dialog.ui`. The port has no GResource, so it
  installs the action itself (`lib/main.rb:51`) and presents an
  `Adwaita::ShortcutsDialog` built in Ruby.
- **`handle_local_options` has no Ruby binding.** `--version` and
  `--new-window`/`-w` are handled from `ARGV` in the launcher and `HANDLES_OPEN`
  file arguments arrive through the application's `open` signal. This is the
  cause of gap C1, not an excuse for it: `add_main_option_entries` is bound and
  is the fix.
- **Upstream's threading model cannot be ported literally.** GTask for
  open/shred/abort plus per-row `GMutex` and `g_main_context_invoke` has no
  equivalent; GTK widgets are main-thread only, so shredding runs in a Ruby
  thread and every UI update is marshalled through `GLib::Idle.add`
  (`lib/window.rb:458-463`, `:477-482`). Loading is the one path that was left
  on the main thread (gap C3).
- **The `RLIMIT_NOFILE/2` file cap** relies on `getrlimit`;
  `Process.getrlimit(:NOFILE)` covers it. The halving is a TODO upstream itself
  admits may be obsolete.
- **`app.open-drive` and the `GVolumeMonitor` device-shredding menu** are
  commented out upstream because Flatpak blocks device files, and are out of
  the parity surface. The `Devices` msgid in the `.pot` comes from that dead
  block.
- **No GSettings schema exists upstream**, so there is no preferences dialog to
  port. A port must not invent one.
- **Translation parity is a separate step from message parity.** 33 `po/`
  catalogues and a 36-message `.pot` exist upstream; the port's gettext wiring
  is in place (`lib/translation.rb`, domain `raider`) but T1 and T2 remain.
