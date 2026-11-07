# Known limitations — raider-rb

Binding and platform facts that make specific gaps expensive to close.
These are evidence for *why* a gap in `PORTING.md` or `.reports/*.md` is
hard, never a reason the gap is closed. A real limitation still leaves the
behaviour owed.

## `Adwaita::Application` / `Adwaita::ApplicationWindow` subclassing

`Adwaita::Application.new` and subclassing `Adwaita::ApplicationWindow`
raise from the Ruby bindings in this environment. Verified by direct
construction attempts under `nix develop --command xvfb-run -a ruby`.
Worked around with `Gtk::Application` plus a plain
`Adwaita::ApplicationWindow` instance (not a subclass) and an explicit
`Adwaita.init` call (`lib/main.rb:92-94`). Every other Adwaita widget
constructs and behaves normally inside that window.

## `GdkPaintable` / `GtkSymbolicPaintable` cannot be implemented from Ruby

Upstream's `src/raider-progress-paintable.c` is a GObject implementing two
GTK interfaces (`GdkPaintable`, `GtkSymbolicPaintable`) with C vfuncs
(`snapshot`, `snapshot_symbolic`). Ruby-GNOME has no supported path to
implement a GI interface's vfuncs from pure Ruby and have GTK call back
into them during its own paint cycle. Substituted with a `Gtk::DrawingArea`
that makes the same Cairo calls `snapshot_symbolic` makes, reading
`style_context.color` at draw time to approximate upstream's
state-following symbolic colour (`lib/progress_paintable.rb`). This read
is the unverified half of gap C7 in `.reports/component-parity.md` — no
screenshot exists comparing the arc's hover/active/insensitive rendering
against upstream's.

## `GOptionEntry` / `g_application_add_main_option_entries` — investigated this round, still unusable

This is gap C1. Investigated directly against the gio2/glib2 bindings this
flake pins:

* `Gio::Application#add_main_option_entries` exists and is a real bound
  method (confirmed via `app.method(:add_main_option_entries).parameters`),
  but it takes GI-marshalled arguments: passing a plain `Hash` for an entry
  raises `wrong argument type Hash (expected GObjectIntrospection::Struct)`.
* The struct it wants, `GLib::OptionEntry`, is **not** defined as a Ruby
  constant after `require "gio2"`, `require "glib2"` or a full
  `require "adwaita"; Adwaita.init` — `GLib::OptionEntry` raises
  `uninitialized constant`, same for `GLib::OptionGroup` and
  `GLib::OptionContext`. Only the two enums it references,
  `GLib::OptionArg` and `GLib::OptionFlags`, are defined.
* The struct *does* exist in the introspection data —
  `GObjectIntrospection::Repository.default.find("GLib", "OptionEntry")`
  returns a real `StructInfo` with fields `long_name`, `short_name`,
  `flags`, `arg`, `arg_data`, `description`, `arg_description` — but
  `Repository#each("GLib")` never yields it, which is why the generic
  GObjectIntrospection loader that would otherwise define
  `GLib::OptionEntry` as a constructible class never runs on it. This
  looks like the struct being excluded from the top-level namespace walk
  because it carries a raw pointer field (`arg_data`) and a union-typed
  field (`arg`), a known-awkward category for GI struct loaders.
* Reaching a constructible instance from there means working with
  `GObjectIntrospection::Struct` at a lower level than any binding call in
  this codebase currently does, including correctly setting `arg_data` to
  a null pointer (the documented way to make `add_main_option_entries`
  deliver the parsed value through the `handle-local-options` /
  `GVariantDict` path instead of a bound C variable) — and no ruby-gnome
  test, example or changelog entry for gio2/glib2 exercises
  `add_main_option_entries` at all, confirmed by grepping both gems' test
  suites in this flake's nix store paths.

Net: the method is bound, the struct type exists in introspection data,
and nothing in this port or the gems it depends on shows a known-working
way to build the struct in Ruby. `--version`/`-v` and
`--new-window`/`-w` are read from `ARGV` by hand instead
(`lib/main.rb:151-153`), which is why `raider --help` does not list them —
that `--help` text comes entirely from GLib's own option parser, which
only sees options registered through `add_main_option_entries`.

## GTask / per-row threading has no literal Ruby equivalent

Upstream uses `GTask` for the open loop, the shred loop and abort, plus a
per-row `GMutex` and `g_main_context_invoke` to get results back onto the
main loop. Ruby-GNOME has no `GTask` wrapper. The port uses a plain Ruby
`Thread` for the shredding, abort and (as of this round, gap C3 closed)
loading paths, with every UI-touching callback marshalled back through
`GLib::Idle.add` (`lib/window.rb`'s `on_main_loop`) — the same
main-thread-only constraint GTK itself imposes. `open_files` now runs the
per-file I/O (`File.exist?`/`File.writable?`) on a worker thread and hands
only the outcome (a toast or a new row) back through the idle queue, the
same split `launch_rows`/`wait_for_rows` already used for shredding and
abort; `open_file` (the single-file entry point several specs call
directly) stays synchronous, matching upstream's own shape — upstream's
`raider_window_open_file` is likewise never called except from inside the
`GTask` worker, never on its own as a synchronous API.

## `app.shortcuts` has no GResource to synthesise it from

Upstream gets the `shortcuts` action for free from a GResource alias
(`shortcuts-dialog.ui`) that GTK's application class wires up
automatically. The port ships no GResource, so the action is installed by
hand (`lib/main.rb:51`) and presents an `Adwaita::ShortcutsDialog` built in
Ruby rather than loaded from a compiled resource. Behaviourally equivalent;
structurally different.
