# Test parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `f98a795e289c3530ea30fd94cff2c5041e9725f6` |
| Upstream tests | **2** |
| Ported (a named port test exists) | **2** |
| Ported **and executed** | **0** |
| Gaps | **2** |
| Spec command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` |
| Spec result, this audit | `96 examples, 0 failures, 2 pending` |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` |
| Drive result, this audit | `202 of 202 checks passed`, 40 steps, 11 components, `DRIVE OK` |

## Censusing upstream

`test-parity/scripts/test-census.sh` on the upstream tree returns **0 rows**.
Upstream has no `test/` or `tests/` directory, no `Test.add_func`, no
`#[cfg(test)]`, no `unittest`, no `it(...)`.

The skill's build-file cross-check finds the suite that does exist. Upstream
registers its tests through meson's `test()`, in `data/meson.build`, which no
regex over source files can see:

```
data/meson.build:12  test('Validate desktop file', desktop_utils, args: [desktop_file])
data/meson.build:27  test('Validate appstream file', appstreamcli, args: ['validate', '--no-net', appstream_file])
```

Two cases. Both are guarded by `find_program(…, required: false)`
(`:10`, `:25`), so upstream skips them when the validator is absent — which
is part of the case, not an exemption from it.

The upstream suite is 2, not 0.

## Suite: data (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `data/meson.build:12` `Validate desktop file` | the **merged** desktop entry — template plus every language's `Name[xx]`/`Comment[xx]` from `po/` — passes `desktop-file-validate`, so the app actually appears in a launcher | `spec/data_files_spec.rb:46` `Validate desktop file` → `:47` `passes desktop-file-validate` | **gap** | the check has never run: `desktop-file-validate` is not on `PATH` in the dev shell, so the example is `pending` and asserts nothing |
| 2 | `data/meson.build:27` `Validate appstream file` | the merged metainfo passes `appstreamcli validate --no-net`, so software centres accept the app's listing | `spec/data_files_spec.rb:59` `Validate appstream file` → `:60` `passes appstreamcli validate --no-net` | **gap** | same: `appstreamcli` is not on `PATH`, the example is `pending`, nothing is asserted |

The mapping is a bijection, the names were kept mechanically from upstream's
`test()` titles, and the port builds the merged output with the same
`msgfmt --desktop` / `msgfmt --xml` invocation and runs the same validator
with the same arguments including `--no-net`. All of that is correct. None of
it has ever been executed.

### Both rows are gaps, and the previous report said they were not

The report at `ad33dea` stated: *"both actually ran and passed on the last
recorded run, so the skip is not hiding anything today."* That is false, and
it was false when it was written — `.rspec_status` has carried
`./spec/data_files_spec.rb[1:1:1] | pending` and `[1:2:1] | pending` the
whole time.

Measured this audit:

```
$ nix develop --command bash -c 'command -v desktop-file-validate appstreamcli msgfmt'
/nix/store/…-gettext-1.0/bin/msgfmt
```

`msgfmt` is there. Neither validator is. The spec run reports:

```
1) DataFiles Validate desktop file passes desktop-file-validate
   # desktop-file-validate is not installed
2) DataFiles Validate appstream file passes appstreamcli validate --no-net
   # appstreamcli is not installed
```

A suite that has never executed a test is not a suite that passed. **The
whole of this port's test parity — all two rows of it — rests on two
examples that have never run once.** The 202-check drive run does not cover
them either: `test/drive_main_window.rb:734` checks `msgfmt is on PATH` and
stops there.

Owed, and it is a one-line change: add `desktop-file-utils` and
`appstream` to the dev shell's `packages` in `flake.nix`, re-run, and record
the result. Until then both rows stay `gap`, and anything that reports
"2/2 ported" without "0/2 executed" beside it is reporting a green that
nobody has seen.

## The port has no inherited safety net

Upstream pinned no behaviour at all. Both of its tests validate generated
metadata. Not one line of `src/corrupt.c`, `src/raider-window.c`,
`src/raider-file-row.c`, `src/raider-progress-paintable.c` or
`src/raider-application.c` is covered by anything upstream wrote.

So even with both rows closed, test parity buys this port nothing: no
upstream knowledge was inherited, and none can be lost. `component-parity.md`
is the only ledger that can catch a behavioural regression here, and it has
eleven open gaps.

## Extra

327 census rows across the port, outside the parity count. They are welcome
and they are not parity work.

| File | Cases | What they drive |
|---|---:|---|
| `test/drive_main_window.rb` | 231 checks in 40 steps | the whole app under a real main loop: the empty state, all seven actions and accelerators, both menus, three files added, all four rejection toasts, the open-file cap, the fatal unknown row, a drop, the four popover states, arc clamping, start/abort/finish, the exit dialog across two windows, the About and shortcuts dialogs, the shredding backend end to end, the build constants, the three data files, `--version` |
| `spec/window_spec.rb` | 24 | widget tree, sizes, pills and `boxed-list`, both menus, the drop target, all four `open_file` branches, clear, the transient labels, both completion callbacks, `request_exit` both ways |
| `spec/app_spec.rb` | 15 | the id and `HANDLES_OPEN`, all seven actions, every accelerator, five About-dialog fields, `--version`/`-v`, `action_quit` across two windows, which arguments reach GApplication |
| `spec/file_row_spec.rb` | 12 | title/subtitle, the absence of style classes and tooltips, the remove icon, the revealer states, the popover, `close`, `launch_shredding`, `shredding_abort`, `wait_for_abort`, a failed shred's row |
| `spec/translation_spec.rb` | 11 | the bound domain, every language in `LINGUAS`, `POTFILES`, every msgid upstream marks, every msgid the `.pot` carries, `%s` not interpolated, mnemonics kept, U+2026 not three dots, a compiled catalogue read |
| `spec/data_files_spec.rb` | 9 (7 extra + the 2 parity rows) | untranslated desktop keys, per-language merges, the metainfo id and licences, `translate="no"` release notes, the service file, the three icons |
| `spec/corrupt_spec.rb` | 6 | the five patterns, a regular file, a zero-byte file, a folder tree, `cancel`, `wait` |
| `spec/progress_paintable_spec.rb` | 6 | the box size, the scale-factor redraw, radius and line width, the clockwise sweep, clamping, the absent check icon |
| `spec/progress_info_popover_spec.rb` | 5 | the bar, and all four text states |
| `spec/shortcuts_dialog_spec.rb` | 5 | the default title, the one section, action-named items, every accelerator-bound action documented |
| `spec/exit_dialog_spec.rb` | 3 | the question, the two responses with appearance and mnemonics, Exit runs the block |

Census note: `test-census.sh` counts 231 rows in `test/drive_main_window.rb`.
`check` is the assertion unit — `GtkDriver#check` (`test/gtk_driver.rb:84`) is
what increments the pass counter — and `step` is grouping, so the script's
combined count over-reports against the runner's 202. The runner's number is
the one to quote.

## Holes in the extra coverage that let open gaps survive

A component no check exercises is unverified, not done. Three of
`component-parity.md`'s gaps exist because nothing drives the path:

* **`app.open` / `app.open-folder` are never driven.** Both file dialogs are
  only checked for existence. `load_into_active_window` and
  `active_port_window` (`lib/main.rb:258-280`) — the code gap C4 is about —
  have no check at all.
* **No check passes a file argument through `App#run`.**
  `spec/app_spec.rb:148`, `:154` assert which strings
  `application_arguments` returns and stop there. That is why gap C10 —
  `raider myfile.txt` opening an empty window — survived to this audit with
  202 green checks on the board.
* **No check runs the app under a non-English locale.** Driver step `:718`
  asserts the marker under the **C** locale only. The German case was run by
  hand in this audit and passes; nothing in the repository runs it.
* **No check fails a write mid-shred**, which is the path gap C11 is about.

## Rules check

* No test was lowered to pass; nothing is commented out.
* No upstream test was merged into another.
* No `n/a`, no `not applicable`. Both upstream rows are **gaps**, with the
  behaviour owed stated.
* The 0-tests reading of the census was rejected on evidence.
* The previous report's "2/2 ported, both ran and passed" was rejected on
  evidence: they have never run.
