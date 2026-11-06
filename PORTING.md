# Porting status — raider-rb

Resume point for the next run. Factual only.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port branch | `ruby` (local only — never pushed, never merged with `origin/main`) |
| Parity units with parity | 8 / 11 |
| Open gaps from the last audit | 3 component (C1, C3, C7) + 3 translation (T1, T2, T3) + 12 accountability (A1-A10, A12, A13) (clean = false) |
| Last recorded test run | 96 passed, 0 failed, 2 pending (`.rspec_status`); `bundle exec rspec` inside `nix develop` |

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

No upstream source file is without a Ruby counterpart.

- `data/raider-screenshot1.png` — copied across as of `ff5772c` (gap C9
  closed).
- `GOptionEntry` command-line declaration (`src/raider-application.c:252-260`)
  — the port still scans `ARGV` instead and declares nothing (gap C1, open).

## Open gaps

As of the audit at `ff5772c` (clean = false). This section is rewritten in
full at every audit, not patched — a previous version of this table said
"16 open" and "93 passed, 0 pending" after eight of those gaps had already
been fixed and the suite had already grown to 96/2-pending; do not trust a
stale copy of this file over `.reports/`. The reports in `.reports/` are the
authority; this section is a pointer to them, updated to match on this date.

Commit `ff5772c` closed eight component gaps (C2, C4, C5, C6, C8, C9, C10,
C11) that were open at the previous audit. Three remain:

- **C1** `--help` lists neither `--version` nor `--new-window`; `lib/main.rb:151-153`
  matches four literal spellings off `ARGV`, so a misspelling is taken as a filename.
- **C3** file loading is synchronous (`lib/window.rb:137-145`); upstream wraps
  the open loop in `g_task_run_in_thread` (`src/raider-window.c:286-292`), so a
  large drop freezes the port's window.
- **C7** the running app has never been compared against a rendered upstream.
  Both visible substitutions (`Gtk::MenuButton` for the progress button,
  `Gtk::DrawingArea` for the paintable) are argued on paper only.

Of the eight closed, five (C4, C5, C8, C9, C10) have no regression check —
see `.reports/accountability-ensurance.md` item A13 before treating them as
settled.

Translation — `.reports/translation-parity.md` (38/38 msgids byte-identical;
three open items, T3 new):

- **T1** `po/pl.po` exists but `po/LINGUAS` omits `pl`, so 34 of 35 catalogues
  are built and a Polish user gets English. Upstream has the same hole;
  `spec/translation_spec.rb:57` currently asserts the hole as expected
  behaviour and must be inverted.
- **T2** `po/com.github.ADBeveridge.Raider.pot` is upstream's build artefact
  verbatim: every `#:` reference names a C or `.blp` file that does not exist
  in this repository, and it is stale against the 38 source keys.
- **T3** nothing in the port checks that any language other than C actually
  reaches the screen; the only end-to-end check (`spec/translation_spec.rb:178`)
  reads a compiled `.mo` file directly rather than calling `_()` under a
  non-English locale.

Accountability — `.reports/accountability-ensurance.md`, A1-A10 carried
forward unresolved across three or more audits, plus two new items this
audit: **A12** (this file was stale against the reports it is supposed to
summarise — being actively corrected right now) and **A13** (the five
unverified fixes named above).

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
