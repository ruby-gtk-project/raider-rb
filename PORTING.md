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
9 of those 11 carry a **parity** verdict there as of this round (C3
closed this round), the other 2 are open gaps (C1, C7 — see Open gaps
below).

## Runtime

Drive command, run this session:

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
```

Result: `205 of 205 checks passed` / `DRIVE OK` — drive_ok=true, 205
passed / 0 failed, 11 components covered (one more check than the
previous round's 204: the new C3 driver step). Re-run live again this
session (no code change): same result, `205 of 205 checks passed`,
`DRIVE OK`.

Spec command, run this session:

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Result: 104 examples, 1 failure — specs 103 passed / 1 failed (three more
examples than the previous round's 101: the C3 regression spec, the
`action_open_folder` window-targeting spec, and the mid-shred-write
`corrupt_spec.rb` case). The one persisting failure is
`spec/data_files_spec.rb:60` (`appstreamcli validate --no-net`):
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
  investigated again this round and still found unreachable from the
  current gio2/glib2 bindings (see `KNOWN_LIMITATIONS.md`).
  `.reports/component-parity.md`.
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

**C3, closed this round.** `lib/window.rb`'s `open_files` now spawns a
`Thread` that does the per-file I/O (`File.exist?`/`File.writable?`) and
hands only the outcome — a toast or a new row — back to the main thread
through `on_main_loop`, the same `GLib::Idle.add` split already used for
shredding and abort. `open_file` (the single-file entry point several
specs call directly) stays synchronous, matching upstream's own shape:
`raider_window_open_file` is likewise never called except from inside
the `GTask` worker. `spec/window_spec.rb` and
`test/drive_main_window.rb` each gained a case that opens many files and
asserts the row count grows across more than one turn of the main loop
rather than jumping straight to the full count — see
`.reports/component-parity.md` and `.reports/test-parity.md` for detail.

**T2 (second half), closed this round.** All 35 `.po` files `msgmerge`d
against the regenerated 39-key `.pot` (`rake gettext:check` passes for
every one, `rake gettext:mo` rebuilt). This surfaced that upstream's own
donated catalogues already carried translations for 3 of the 4 new keys
— they were simply unreachable against the smaller, pre-fix `.pot` this
port's own tooling generated before this round. See
`.reports/translation-parity.md` for the per-key counts; still owed: 6
`.po` files have no `Keywords=` translation because upstream itself
never translated that line, and `msgmerge` flagged roughly a dozen
entries across 10 catalogues `fuzzy`, which needs a human translator's
confirmation, not a further automated pass.

**T2 (first half) and T4, closed a previous round.** `Rakefile`'s `gettext:pot:create` task
now runs two `xgettext` passes (`--language=Desktop`, and
`--its=.../metainfo.its`) over the two `data/*.in.in` templates
`po/POTFILES` names, and folds their output into the Ruby-sourced `.pot`
with `msgcat --use-first` — the same two extractors meson's own
`i18n.gettext` uses for these file types internally. `po/com.github.ADBeveridge.Raider.pot`
now carries **39** msgids (was 35); a full key-set diff (not just the
`grep -c` total) shows exactly the 4 data-only keys added and 0 removed.
See `.reports/translation-parity.md` for the full key-set diff. At the
end of that round those 4 keys had no `.po` translation reconciled into
any of the 35 catalogues yet — the admission immediately above this one
(recorded, not deleted, as A15/T4's own standard asks) is that I stopped
at regenerating the template and called the row closed without finishing
the merge it exists to drive. That merge is what T2 (second half) above
closes this round.

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
- `GTask` has no Ruby-GNOME wrapper; the port uses a plain `Thread` plus
  `GLib::Idle.add` for shredding, abort and (as of this round) loading
  instead. Not a remaining blocker for C3 — the substitute pattern closed
  it — but still the reason none of the three is a literal `GTask` port.
