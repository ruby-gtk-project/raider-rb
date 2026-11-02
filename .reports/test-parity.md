# Test parity — raider-rb

| | |
|---|---|
| Upstream | `main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `fe65d4fc528569b77548e6cf8bb744135603ce5b` |
| Upstream tests | **2** |
| Ported | **0** |
| Gaps | **2** |
| Test command | `bundle exec rspec` (declared; **it does not run** — see below) |

## The census

Upstream is a C app with no unit-test framework: no `test/` or `tests/`
directory, no `g_test_*`, no `Test.add_func`, no `#[test]`, no `unittest`, no
`pytest`. That part of a "zero tests upstream" reading is right.

It is still **not** a zero-test project. `data/meson.build` registers two
`test()` targets, and they run under `meson test` like any other:

```
data/meson.build:12   test('Validate desktop file',   desktop-file-validate <desktop_file>)
data/meson.build:27   test('Validate appstream file', appstreamcli validate --no-net <appstream_file>)
```

Both are guarded by `find_program(..., required: false)`, so they are skipped
where the validators are absent — which is why a quick look reports none, and
why reporting 0/0 here would be wrong in the direction that flatters the port.

## Suite: data/meson.build (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `data/meson.build:12` `Validate desktop file` | the merged, translated `.desktop` passes `desktop-file-validate`: valid `Name`, `Comment`, `Exec`, `Icon`, `Categories`, `Keywords`, `DBusActivatable`, `X-GNOME-UsesNotifications`, and all 34 translated `Name[xx]`/`Comment[xx]` lines | — | **gap** | The port ships no `.desktop` file at all (`.reports/component-parity.md`, `data/` unit). A Ruby test must build the desktop entry from the port's own metadata plus `po/`, run `desktop-file-validate` on the result, and fail if the validator does |
| 2 | `data/meson.build:27` `Validate appstream file` | the merged, translated metainfo passes `appstreamcli validate --no-net`: component id, licences, name, summary, both description paragraphs, `launchable`, the four `url` entries, developer, releases | — | **gap** | The port ships no metainfo file. A Ruby test must build it, run `appstreamcli validate --no-net`, and fail on any error |

Both gaps are blocked on one component gap, not on test infrastructure: the
files they validate do not exist in the port. They close when `data/` is
ported, and not before.

## The port's own suite

The port has **no tests of its own either**, and its declared test command does
not work:

- `find spec -name '*_spec.rb'` → **0 files**. `spec/` contains only
  `spec_helper.rb` and `README.md`.
- `spec/spec_helper.rb:30` does `require "raider/rb"`. There is no
  `lib/raider/rb.rb` — only `lib/raider/rb/version.rb`. Verified:
  `ruby -Ilib -e 'require "raider/rb"'` →
  `cannot load such file -- raider/rb (LoadError)`. So the suite cannot load
  even if an example existed.
- `.simplecov`, `.rspec`, `.rspec_status`, `.rubocop_rspec.yml`,
  `gemfiles/modular/rspec.gemfile` and `bin/turbo_tests2` are all wired up
  around a suite with nothing in it.

So:

> **Parity is 0/2, and the port has no safety net of its own on top of that.**
> Upstream pins two things and the port pins neither. Every behaviour in
> `.reports/component-parity.md` that is marked "driven" was driven by a
> throwaway script in a scratch directory for this audit; **none of it is
> committed, none of it runs in CI, and nothing will catch any of it
> regressing.** The 1,795 lines under `lib/` and `exe/` are covered by zero
> committed assertions.

## Extra

Nothing. There is no `## Extra` section to write — not one Ruby test exists.

The checks this audit ran, which somebody should now turn into committed tests
(they are listed so the work is transcription, not invention):

- 42 widget / property read-backs on `Window`, `FileRow`,
  `ProgressInfoPopover`, `ProgressPaintable`, `ExitDialog`, `ShortcutsDialog`
  and `App` — types, CSS classes, labels, icons, tooltips, menu item counts,
  stack page names, drop-target gtypes, action list and all seven accelerators.
- `Window#open_file` for all five outcomes: accepted, duplicate, missing,
  unwritable, over the `RLIMIT_NOFILE / 2` cap.
- `Window#clear_files` → zero rows and `empty_page`.
- A full two-file shred run, pumping `GLib::MainContext`: files gone from disk,
  rows gone, `empty_page`, `shredding?` false, `open_revealer` restored.
- `ProgressInfoPopover` in all four text states.
- `Corrupt` on a regular file, a folder, and a zero-byte file.
- `App#run` with `--version`.

## Rules this ledger is obeying

- Upstream's two tests keep their rows and stay `gap` until a Ruby test exists
  by name. "The port has no `.desktop` to validate" is why the gap is hard, and
  it is not a closure.
- The test command is named in the header **with the fact that it is broken**,
  because reporting `bundle exec rspec` as the command without that is
  reporting an unrun check as a passed one.
