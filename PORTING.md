# Porting status — raider-rb

Resume point for the next run. Factual only — every number below was
produced by actually running the command named next to it, this session.

## Upstream

raider ("File Shredder") — a GTK4/Libadwaita desktop app, implemented
upstream in C with the UI in blueprint (`.blp`) files compiled into a
GResource, built with meson. This repository (`raider-rb`) is a Ruby
GTK4/Libadwaita port of that app. The spec lives on the `origin/main` ref
of this same repository; read it with `git show origin/main:<path>` and
`git ls-tree -r --name-only origin/main`. The port (`ruby` branch) is
written from scratch against that spec — it is never checked out and
never merged.

Upstream lets a user add files or folders by button, menu, command line or
drag-and-drop, lists them as a boxed list, then overwrites each one with
five fixed byte patterns and unlinks it, with per-file progress, abort,
toasts and a finish notification.

## Done

Components implemented and observed working this session (via
`test/drive_main_window.rb`, see Runtime below) or by the spec suite:

| Port | Upstream |
|---|---|
| `lib/main.rb` | `src/main.c`, `src/raider-application.c` |
| `lib/window.rb` | `src/raider-window.blp`, `src/raider-window.c` |
| `lib/file_row.rb` | `src/raider-file-row.blp`, `src/raider-file-row.c` |
| `lib/progress_info_popover.rb` | `src/raider-progress-info-popover.blp`, `src/raider-progress-info-popover.c` |
| `lib/progress_paintable.rb` | `src/raider-progress-paintable.c` (substituted — `GdkPaintable`/`GtkSymbolicPaintable` vfuncs are not implementable from Ruby; see `KNOWN_LIMITATIONS.md`) |
| `lib/corrupt.rb` | `src/corrupt.c`, `src/corrupt.h` |
| `lib/shortcuts_dialog.rb` | `src/raider-shortcuts.blp` (built in Ruby, not loaded from a `.ui` file; see `KNOWN_LIMITATIONS.md`) |
| `lib/exit_dialog.rb` | the `raider_window_exit` alert dialog in `src/raider-window.c` |
| `lib/package_config.rb` | the `config_h` block in `meson.build` |
| `lib/translation.rb` | the gettext setup in `src/main.c` |
| `lib/data_files.rb` | `data/meson.build`, `data/icons/meson.build`, `po/meson.build` |
| `data/`, `po/` | upstream `data/` templates and icons, 35 `.po` plus the `.pot`; all 35 `.mo` built by `rake gettext:mo` |

`src/meson.build`, `src/raider.gresource.xml` and the top-level
`meson.build` have no single Ruby counterpart: there is no GResource to
compile and no meson build to replace, so the gem's `Rakefile`,
`flake.nix` and `lib/data_files.rb` carry that work between them instead.

11 upstream units are tracked for parity in `.reports/component-parity.md`;
8 of those 11 carry a **parity** verdict there, the other 3 are open gaps
(C1, C3, C7 — see Open gaps below).

## Runtime

Drive command, run this session:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
```

Result: `204 of 204 checks passed` / `DRIVE OK` — drive_ok=true, 204
passed / 0 failed, 11 components covered.

Spec command, run this session:

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Result: 101 examples, 1 failure — specs 100 passed / 1 failed. The failure
is `spec/data_files_spec.rb:60` (`appstreamcli validate --no-net`):
`developer-id-invalid io.github.ADBeveridge` against the port's
byte-identical copy of upstream's own metainfo. This is upstream's own
data defect, reproduced faithfully, not a regression introduced by the
port.

## Not started

No upstream source file is entirely without a Ruby counterpart. The one
upstream-declared surface still unimplemented is the `GOptionEntry`
command-line declaration (`src/raider-application.c:252-260`): the port
scans `ARGV` by hand instead of registering options through
`g_application_add_main_option_entries`, so `raider --help` does not list
`--version`/`-v` or `--new-window`/`-w` (this is gap C1 below).

## Open gaps

- **C1** — `GOptionEntry` command-line registration not implemented;
  investigated and found unreachable from the current gio2/glib2
  bindings (see `KNOWN_LIMITATIONS.md`). `.reports/component-parity.md`.
- **C3** — `open_files`/`open_file` runs synchronously in the port where
  upstream uses a `GTask` worker thread, so a large drop can freeze the
  window; unchanged, no check exercises it. `.reports/component-parity.md`,
  `.reports/test-parity.md`.
- **C7** — the progress button/paintable substitution
  (`Gtk::MenuButton` + `Gtk::DrawingArea` standing in for upstream's plain
  button and custom `GdkPaintable`) has never been rendered side by side
  with upstream; unverified whether it changes rendered size or symbolic
  colour under hover/active/insensitive states.
  `.reports/component-parity.md`, `.reports/component-inventory.md`.
- **A14** — accountability finding: a past commit asserted T2 complete
  without the diff that would have caught the regression recorded as T4;
  recorded as closed in `.reports/accountability-ensurance.md` now that
  `.reports/translation-parity.md` carries that diff explicitly, but the
  historical finding itself is not deleted.

**T2 and T4, closed this round.** `Rakefile`'s `gettext:pot:create` task
now runs two `xgettext` passes (`--language=Desktop`, and
`--its=.../metainfo.its`) over the two `data/*.in.in` templates
`po/POTFILES` names, and folds their output into the Ruby-sourced `.pot`
with `msgcat --use-first` — the same two extractors meson's own
`i18n.gettext` uses for these file types internally. `po/com.github.ADBeveridge.Raider.pot`
now carries **39** msgids (was 35); a full key-set diff (not just the
`grep -c` total) shows exactly the 4 data-only keys added and 0 removed.
See `.reports/translation-parity.md` for the diff and for what remains
owed (those 4 keys have no `.po` translation yet; the 35 catalogues were
deliberately left untouched this round).

## Blockers

Documented in full in `KNOWN_LIMITATIONS.md`; summarized here:

- `Adwaita::Application.new` and subclassing `Adwaita::ApplicationWindow`
  raise from the Ruby bindings in this environment. Worked around with
  `Gtk::Application` plus a plain `Adwaita::ApplicationWindow` instance.
- `GdkPaintable`/`GtkSymbolicPaintable` cannot be implemented from Ruby —
  no supported path for GI interface vfuncs to be called back into from
  pure Ruby. Substituted with a `Gtk::DrawingArea` (root of gap C7 above).
- `GLib::OptionEntry` is present in GI introspection data but excluded
  from the glib2 gem's top-level namespace walk (a raw-pointer and
  union-typed field make it an awkward case for the generic GI struct
  loader), so `g_application_add_main_option_entries` cannot be driven
  from Ruby without lower-level `GObjectIntrospection::Struct` work that
  no example in either gem demonstrates (root of gap C1 above).
- `GTask` has no Ruby-GNOME wrapper; the port uses a plain `Thread` for
  shredding and abort instead, which is why C3 (synchronous `open_files`)
  remains open rather than literally ported.
