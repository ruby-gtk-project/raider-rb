# Test parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Upstream tests | **2** |
| Ported | **2** |
| Gaps | **0** |
| Test command | `bundle exec rspec` (inside `nix develop`) |
| Last recorded run | 93 passed, 0 failed, 0 pending (`.rspec_status`) |

## Censusing upstream, and why the script's answer was wrong

`test-parity/scripts/test-census.sh` on the upstream tree returns **0 rows**.
Upstream has no `test/` or `tests/` directory, no `Test.add_func`, no
`#[cfg(test)]`, no `unittest`, no `it(...)`.

The skill's build-file cross-check is what finds the suite that does exist.
Upstream registers tests through meson's `test()`, in `data/meson.build`, which
no regex over source files can see:

```sh
grep -rn "test(" up/data/meson.build
#  12:  test('Validate desktop file', desktop_utils, args: [desktop_file])
#  27:  test('Validate appstream file', appstreamcli, args: ['validate', '--no-net', appstream_file])
```

Two cases. Both are guarded by `find_program(..., required: false)`
(`data/meson.build:10`, `:25`), so upstream skips them when the validator is
absent — which is part of the case, not an excuse for it.

So the upstream suite is 2, not 0. Reporting 0/0 here would have been the
comfortable answer and the wrong one.

## Suite: data (2 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `data/meson.build:12` `Validate desktop file` | the **merged** desktop entry — template plus every language's `Name[xx]`/`Comment[xx]` from `po/` — passes `desktop-file-validate`, so the app actually appears in a launcher | `spec/data_files_spec.rb:46` `Validate desktop file` → `:47` `passes desktop-file-validate` | ported |
| 2 | `data/meson.build:27` `Validate appstream file` | the merged metainfo passes `appstreamcli validate --no-net`, so software centres accept the app's listing | `spec/data_files_spec.rb:59` `Validate appstream file` → `:60` `passes appstreamcli validate --no-net` | ported |

Each pair tests the same thing in the same way: the port builds the merged
output with the same `msgfmt --desktop` / `msgfmt --xml` invocation
(`lib/data_files.rb:356-369`) and runs the same validator with the same
arguments, including `--no-net`. Both mirror upstream's conditional skip
(`spec/data_files_spec.rb:50`, `:63`) — and both actually ran and passed on the
last recorded run, so the skip is not hiding anything today.

Counts are equal, the mapping is a bijection, and the names were kept
mechanically from upstream's `test()` titles.

## The port has no inherited safety net

Say it plainly, because 2/2 reads like a pass and is not one: **upstream pinned
no behaviour at all.** Both of its tests validate generated metadata. Not one
line of `src/corrupt.c`, `src/raider-window.c`, `src/raider-file-row.c` or
`src/raider-application.c` is covered by anything upstream wrote. Test parity
is met and it buys the port nothing — every behavioural check in this port was
invented here, so no upstream knowledge was inherited and none can be lost.

That also means the test-parity ledger cannot catch a behavioural regression in
this port. `component-parity.md` is the only ledger that can, and it has nine
open gaps.

## Extra

91 examples with no upstream counterpart. They stay extra and stay outside the
count.

| File | Examples | What they drive |
|---|---:|---|
| `spec/window_spec.rb` | 24 | widget tree, sizes, pills and `boxed-list`, both menus, the drop target, all four `open_file` branches, the open-file cap, clear, the transient labels on start and abort, both completion callbacks, `request_exit` both ways |
| `spec/app_spec.rb` | 13 | the id and `HANDLES_OPEN`, all seven actions, every accelerator, five About-dialog fields, `--version`/`-v`, `action_quit` across two windows, which arguments reach GApplication |
| `spec/file_row_spec.rb` | 11 | title/subtitle, the absence of style classes and tooltips, the remove icon, the revealer states, the popover, `close`, `launch_shredding`, `shredding_abort`, `wait_for_abort` |
| `spec/translation_spec.rb` | 11 | the bound domain, every language in `LINGUAS`, `POTFILES`, every msgid upstream marks, every msgid the `.pot` carries, `%s` not interpolated, mnemonics kept, U+2026 not three dots, a compiled catalogue found and used |
| `spec/data_files_spec.rb` | 7 (+ the 2 ported above) | untranslated desktop keys, per-language merges, the metainfo id and licences, `translate="no"` release notes, the service file, the three icons |
| `spec/corrupt_spec.rb` | 6 | the five patterns, a regular file, a zero-byte file, a folder tree, `cancel`, `wait` |
| `spec/progress_paintable_spec.rb` | 6 | the box size, the scale-factor redraw, radius and line width, the clockwise sweep, clamping, the absent check icon |
| `spec/progress_info_popover_spec.rb` | 5 | the bar, and all four text states |
| `spec/shortcuts_dialog_spec.rb` | 5 | the default title, the one section, action-named items, every accelerator-bound action documented |
| `spec/exit_dialog_spec.rb` | 3 | the question, the two responses with appearance and mnemonics, Exit runs the block |

Census note: `test-census.sh` on the port reports 93 rows against RSpec's 93
recorded examples, so `it` is this suite's assertion unit and no identifier
repeats across a file.

## Rules check

* No test was lowered to pass; nothing is commented out.
* No upstream test was merged into another.
* No `n/a`, no `skipped` state: both upstream rows are `ported`.
* The 0-tests reading was rejected on evidence, not softened.
