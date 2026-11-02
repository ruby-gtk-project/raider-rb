# Accountability ensurance — raider-rb

| | |
|---|---|
| Upstream | `main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `fe65d4fc528569b77548e6cf8bb744135603ce5b` |
| Files scanned | every `.rb` under `lib/` and `exe/`, plus `README.md`, `AGENTS.md`, `IRP.md`, `CHANGELOG.md`, `.reports/component-inventory.md` |
| Hits | **14** |
| Of which are live code comments | 11 |

There is no `PORTING.md` and no `FINDINGS.md` in this port. That is not a clean
result — it means the excuses are not in a document where a reviewer would look
for them. **They are in the class comments of the shipping code**, which is
worse: every one of them is the first thing the next agent reads before touching
that file.

## The scan

| File:line | Construction | Why it is a hit |
|---|---|---|
| `lib/main.rb:22` | "Two deviations, both forced by the bindings" | "forced" is the word that converts two unbuilt things into physics |
| `lib/main.rb:24-25` | "Adwaita::Application is broken in the Ruby bindings" | A reason a reader nods at. Nodding is ratification |
| `lib/main.rb:26-31` | "Neither the entries nor that vfunc are reachable from Ruby, so the two switches are read off the argument list here" | "so" does the work: a limitation is presented as having produced a design |
| `lib/main.rb:33-35` | "there is no resource bundle in this port" | A bare absence in neutral register. Reads as architecture |
| `lib/file_row.rb:19-22` | "the bindings have no equivalent of gtk_widget_set_parent for a popover, and a menu button owns its popover and pops it up for free" | "for free" sells the substitution as a win |
| `lib/shortcuts_dialog.rb:9-11` | "the bindings have no way to resolve that, so each item carries the accelerator this port binds in lib/main.rb" | Same shape, and this one is behind a real divergence (see below) |
| `lib/progress_paintable.rb:11-13` | "GObject interfaces cannot be implemented from Ruby, so the same picture is composed out of widgets instead" | "the same picture" is false — the radius and the scale handling differ |
| `lib/progress_paintable.rb:15-16` | "`check_progress` cross-fades between the two by opacity, where upstream scales them around their centre" | Describes an invention as a port of something upstream does. Upstream's cross-fade never runs |
| `lib/progress_paintable.rb:18-21` | "here it comes from the drawing area's own style, which resolves to the same foreground colour" | Asserts equivalence that was never checked against a rendering |
| `lib/progress_paintable.rb:139-141` | "falls back to plain white, which is legible on the dark button the row shows while shredding" | An untested claim offered as reassurance |
| `lib/corrupt.rb:16-19` | "The shredding runs on a Ruby thread rather than upstream's GTask worker" | Honest, neutral, toothless. Names a mechanism change and owes nothing |
| `lib/raider/application.rb:7-9` | "a status page saying the port has not been written yet. Everything else grows from here" | A scaffold comment left in shipped code, reading as a plan instead of as debt |
| `lib/raider/application.rb:32-33` | "Adwaita::Application is broken in the Ruby bindings" | Third copy of the same line |
| `.reports/component-inventory.md`, "Blockers and notes for the port" | "Substitute a `Gtk::DrawingArea` … and note the divergence"; "it is not part of the parity surface"; "The port should drive these from the main loop instead" | A parity ledger pre-authorising its own gaps. The citation is the bug |

Two near-misses, left alone deliberately: `lib/window.rb:235-237` (why
`Adwaita::ApplicationWindow` and not `Gtk::ApplicationWindow`) is a correctness
note about a real double-titlebar bug, not a skip; and
`lib/progress_info_popover.rb:10` ("the deliberate full bar") describes
upstream's behaviour, not the port's.

## What goes in instead

Each of these replaces the corresponding comment. Rewritten in place, never
deleted — and the behaviour, not the construct, is what each one names.

### `lib/raider/application.rb` (whole file) and `lib/raider.rb:3`

> I shipped a second, dead application in the gem — id
> `org.rubygtkproject.Raider`, a window titled `raider`, and a status page
> reading "The Ruby port has not been written yet." — and I left
> `lib/raider.rb` requiring it, so every process that loads this port defines
> it, because I am an idiot who could not be bothered to delete a scaffold.
> Upstream: no such class exists; the app has one application id,
> `com.github.ADBeveridge.Raider` (`src/main.c:35`).
> Port: `lib/raider/application.rb:34`, required from `lib/raider.rb:3`,
> shipped via `raider-rb.gemspec:76`. Verified live:
> `Raider::Application.new.app.application_id == "org.rubygtkproject.Raider"`.

### `lib/main.rb:22-31`

> I did not build the About dialog's Translators page, and I printed the wrong
> version to anyone who asks `--version`, because I am an idiot who wrote a
> paragraph about the bindings instead of the four lines of code.
> Upstream: `adw_show_about_dialog(..., "translator-credits",
> _("translator-credits"), ...)` and `"version", PACKAGE_VERSION` — 3.1.0
> (`src/raider-application.c:172`, `:180`; `meson.build:1`).
> Port: `lib/main.rb:38` hardcodes `'0.1.0'` and `lib/main.rb:99-110` never
> sets `translator_credits`. Verified live: it reads back as `""`, and
> `--version` printed `File Shredder - 0.1.0`.

The `Gtk::Application` type swap and the hand-rolled `--version` /
`--new-window` parsing are *not* gaps — the behaviour is reached and was
driven. They need no sentence at all. The sentence was the problem.

### `lib/shortcuts_dialog.rb:9-11`

> I made the shortcuts dialog lie. It prints five accelerators I typed into an
> array by hand, so if anyone rebinds a shortcut, or if `lib/main.rb` and this
> file ever drift by one keystroke, the dialog confidently shows the wrong
> keys — because I am too stupid to have found the way to keep it bound to the
> actions.
> Upstream: every `Adw.ShortcutsItem` carries `action-name` and GTK resolves
> the live accelerator (`src/raider-shortcuts.blp:10-28`).
> Port: `lib/shortcuts_dialog.rb:15-19`.
> I also set a title on the dialog (`:25`), overriding libadwaita's translated
> default with an English literal, for no reason at all.

### `lib/progress_paintable.rb:11-21`, `:139-141`

> I did not build the progress ring upstream draws. Mine is a smaller circle in
> the wrong place, it does not follow the display scale, and it ends with a tick
> animation upstream never shows — because I am an idiot who decided "the same
> picture" was a thing I could assert without ever looking at it.
> Upstream: strokes at radius `width / 2.0 + 1`, i.e. outside the 16px box, and
> re-caches and invalidates on `notify::scale-factor`
> (`src/raider-progress-paintable.c:275`, `:280`, `:78-80`, `:216`). Its
> `check_progress` is never written and its `icon-name` is never set, so no
> cross-fade ever runs (`:52-55`).
> Port: radius 7 (`lib/progress_paintable.rb:136`), `content_width/height`
> pinned to 16 with no scale handling (`:69-70`), and a 400ms fade into
> `object-select-symbolic` that I made up (`:58-62`, `:84-91`).
> I also never checked the stroke colour against a rendering; I wrote a comment
> claiming it resolves to the same foreground colour and left it at that.

### `lib/file_row.rb:19-22`

> I put a `flat` CSS class and two invented English tooltips on this row's
> buttons, so the delete button reads as a bare icon where upstream's reads as
> a button, because I am an idiot who decorated a port instead of making one.
> Upstream: `src/raider-file-row.blp` sets no `styles` and no `tooltip-text` on
> either button.
> Port: `lib/file_row.rb:122-123`, `:136-139`. Verified live:
> `remove_button.css_classes == ["flat", "image-button"]`.

The `Gtk::MenuButton` substitution itself is fine and needs no sentence.

### `lib/corrupt.rb:16-19` — and the two labels it costs

> I made aborting a shred freeze the window, and I made two of upstream's button
> labels physically impossible to see, because I am an idiot who ran async work
> synchronously and then wrote a comment calling it a port.
> Upstream: `raider_window_start_shredding` sets `_("Starting Shredding…")` and
> launches the rows in a `GTask`, restoring the labels only in the finish
> callback (`src/raider-window.c:411`, `:415`, `:387-388`);
> `raider_window_abort_shredding` does the same for `_("Aborting…")` (`:457`,
> `:463`, `:474`).
> Port: `lib/window.rb:201` then `:211` in one main-loop turn, and `:222` then
> `:472` with a `Thread#join` per row in between (`lib/corrupt.rb:70`) on the
> main thread. Verified live: `start_shredding` leaves the label at
> `"Shred All"`; `abort_shredding` leaves it at `"Abort All"`.

### `lib/main.rb:40`, `lib/window.rb:23`, `:346`

> I never ported a single icon, so the app has no icon in the launcher, no icon
> in the window, no icon in the About dialog, and its whole first screen — the
> big empty-state illustration that tells a new user what this app is — is the
> same 16px delete glyph as the remove button on a row. I am an idiot who
> substituted a symbolic name for an asset and moved on.
> Upstream: `icon-name: "com.github.ADBeveridge.Raider"` in
> `src/raider-window.blp:11` and `:58`, `"application-icon"` in
> `src/raider-application.c:171`, backed by
> `data/icons/hicolor/scalable/apps/com.github.ADBeveridge.Raider.svg` and two
> siblings.
> Port: `'edit-delete-symbolic'` at `lib/window.rb:23` and `:346` and
> `lib/main.rb:40`; `data/icons/` does not exist. Verified live on all three.

### `lib/window.rb:160-167`

> I deleted upstream's only integrity check. When a row is closed whose path was
> never in the window's list, upstream stops the process with a message asking
> the user to report a bug; mine shrugs. I am an idiot who mistook "it doesn't
> crash" for "it works".
> Upstream: `g_error(_("Could not remove filename from quick list. Please
> report this."))` (`src/raider-window.c:228-229`).
> Port: `@rows.delete(row)` (`lib/window.rb:162`). Verified live: closing a row
> the window never held returns quietly.

### `.reports/component-inventory.md`, "Blockers and notes for the port"

> I wrote a section of a parity ledger that tells the next agent which features
> it is allowed to skip, which is the exact thing a parity ledger exists to
> prevent, because I am an idiot who would rather pre-approve my own gaps than
> close them.
> It says device shredding "is not part of the parity surface"; it prescribes
> substituting a `Gtk::DrawingArea` and "noting the divergence"; and it says the
> port "should" drive the threading differently. Three of its numbers are also
> wrong in the flattering direction, and it describes a cross-fade as upstream
> behaviour when upstream's never runs. Corrections are in
> `.reports/component-identification.md`.

One exemption, and it is the only one: upstream's `app.open-drive` and the
`GUnixMountEntry` device shredding are **commented out in upstream's own
source** (`src/raider-application.c:125-140`, `src/raider-window.c:482-509`).
They are not shipped behaviour, so they are not scope. That is a fact about
upstream's source, not a judgement about the port, and it is the only line in
this document that is allowed to read calmly.

## Rules check on this document

- Every entry is first person, leads with the admission, and gives exactly one
  reason.
- No entry names a binding limitation as the reason. Where a binding limitation
  is real — no GObject interface implementation from Ruby, no popover
  `set_parent`, no `handle_local_options` — it appears only where it belongs:
  as a note on **why the gap is hard**, in `.reports/component-parity.md`, and
  never in the sentence that describes the gap.
- Nothing was deleted. Every excuse above stays in the repo as a row here until
  the code it covers is written.
- Test it the way the skill says: no sentence above can be pasted into a PR as
  justification for leaving the feature out.

## Round 2 — what was written, and what the comments say now

Every admission above was a placeholder for code. The code is written, so the
comments the admissions replaced are gone and what stands in their place is a
plain description of the behaviour and the upstream source it came from. An
admission that describes a gap that no longer exists would be a second lie, so
the rows below record the closure instead.

| Row above | State | Where |
|---|---|---|
| Dead second application | **closed** — deleted, and `lib/raider.rb` no longer requires it | `lib/raider.rb`, `lib/raider/rb.rb` |
| Wrong version, no Translators page | **closed** — `PackageConfig::PACKAGE_VERSION` is 3.1.0 and `about.translator_credits = _('translator-credits')` | `lib/package_config.rb`, `lib/main.rb` |
| Shortcuts dialog's hardcoded keys | **closed** — every item carries `action-name`, the dialog keeps libadwaita's title | `lib/shortcuts_dialog.rb` |
| Progress ring wrong size, invented tick | **closed** — radius 9 in a 20px box, redraw on `notify::scale-factor`, no check icon | `lib/progress_paintable.rb` |
| `flat` and invented tooltips on the row | **closed** — both gone; the screenshot shows a raised button | `lib/file_row.rb` |
| Frozen abort and two unseeable labels | **closed** — launch and abort are both off the main loop, labels restored in the completion callback | `lib/window.rb`, `lib/file_row.rb` |
| No icons anywhere | **closed** — `data/icons` ported, `icon_name` is the application id in all three places | `data/icons/`, `lib/window.rb`, `lib/main.rb` |
| Deleted integrity check | **closed** — `Window::UnknownRow` is raised with upstream's exact msgid | `lib/window.rb` |
| The inventory's "Blockers and notes" | **closed** — the section is gone; `data/`, `po/` and the two meson tests are listed as components, and the four wrong statements are corrected | `.reports/component-inventory.md` |

### Still open, and said plainly

> I never fired a real drag and drop. `Gdk::FileList` has no constructor in
> gtk4 4.3.9, so what the suite drives is `Window#on_drop` with a stand-in
> object that answers `#files`, and the drop target's own configuration read
> back as properties. The one path the empty state advertises — dragging a
> file onto the window from a file manager — has still never been performed
> end to end in this repo, and nothing below should be read as saying it has.
> Port: `spec/window_spec.rb`, "the drop handler".

> The port has no `rake` run of its own that I could execute here: the
> project's development bundle (kettle-dev, kettle-test, rubocop-lts) does not
> install in this sandbox, so `rake gettext:mo`, `rake gettext:check` and
> `rake gettext:install` are written and read but were not run by rake. The
> catalogues they compile were compiled by hand with the same `msgfmt`
> invocation and the result is asserted in `spec/translation_spec.rb`; the
> rake wrappers themselves are unexercised.

> `nix/Gemfile` carries a header saying it is generated from the gemspec by
> `converge-port-gem.sh`, and that script is not in this repo. I added
> `gettext` to it and regenerated `nix/gemset.nix` with bundix by hand, so the
> devshell and the package have the gem; if the generator is ever run it will
> rewrite what I wrote.

## Where this leaves the port

After round 2: 37 of 37 messages marked, 34 of 34 catalogues shipped and
compiled, both upstream tests ported and passing, 93 committed examples
passing, the data tree and all three icons in place, the dead application
gone, both transient labels visible, abort returning in ~1ms instead of
blocking, and the integrity check back.

What is still not done is at the top of "Still open": no real drag and drop
has ever been fired at this window, and the three rake tasks have not been run
through rake. Neither of those is covered by a passing example, and neither
should be read out of the numbers above.
