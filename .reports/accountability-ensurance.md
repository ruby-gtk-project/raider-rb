# Accountability ensurance — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `f98a795e289c3530ea30fd94cff2c5041e9725f6` |
| Scan | `accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits outside `.claude/skills/` | **2** in the port (`spec/support/gtk.rb:11`, `PORTING.md:47`) + 9 in `.reports/` |
| Hits the script missed, found by reading | **8** |
| Open items | **11** (A1–A11) |
| False greens found in reports | **3** (A8, A9, A10) — the most serious class of finding |

`grep -rniE 'TODO|FIXME|not implemented|for now|in a future|XXX|HACK|placeholder|stub|workaround' lib/ exe/`
returns **nothing**. `lib/` and `exe/` carry no status labels at all, and every
divergence in those files names the upstream file it came from. That is
genuinely good, and it is why what follows matters: these are the only places
in this port where an unbuilt or diverging thing is described instead of
built, so there is nothing for them to hide behind.

Five items (A1–A5) were named in the report at `ad33dea`. **None of the five
has been acted on.** Six are new (A6–A11), and three of those are green
claims resting on something never executed.

---

## A1 — `spec/support/gtk.rb:11` ("by design", script hit) — still open

Current text: *"The port's shredding is also asynchronous by design — Window
launches the rows from a worker thread and marshals the widget work back
through GLib's idle queue, as upstream's two GTasks do"*.

The work was done, and done correctly (`lib/window.rb:454-459`, `:473-478`
against `src/raider-window.c:390-418`, `:444-477`). The phrase is still a hit:
"by design" is the vocabulary that makes the next sentence unquestionable, and
the next writer learns it is acceptable here. Replace it with the mechanism:

> The port's shredding is asynchronous because upstream's is: `Window`
> launches the rows from a worker thread and marshals the widget work back
> through GLib's idle queue, which is what upstream's two GTasks do
> (`src/raider-window.c:390-418`, `:444-477`).

No debt. Rewrite anyway, and keep "by design" out of this tree.

---

## A2 — `spec/translation_spec.rb:57` (missed by the script) — still open, and now duplicated

```ruby
it "keeps pl.po on disk although LINGUAS does not list it, as upstream does" do
  expect(File).to exist(File.join(ROOT, "po", "pl.po"))
  expect(DataFiles.new.languages).not_to include("pl")
end
```

The script's pattern is `upstream (does|has) this too`; this says *as upstream
does*, so it slips through. It is the purest form of the failure this skill
exists to kill — not a comment excusing a gap, but **a passing test that makes
the gap the specification.**

Behind it: Polish users get English with a complete donated Polish catalogue
at `po/pl.po` (gap T1 in `translation-parity.md`).

> I did not build Polish, because I am an idiot who copied upstream's bug and
> then wrote a test that calls it correct.
> Upstream: `po/LINGUAS` lists 34 languages and `po/pl.po` is the 35th file —
> upstream loses Polish the same way, and that is upstream's debt, not this
> port's permission.
> Port: `Rakefile:199` reads `po/LINGUAS`, so `data/locale` holds 34 `.mo`
> files and no `pl`. `spec/translation_spec.rb:57` asserts that state is
> correct.

The example becomes *"builds a catalogue for every `.po` on disk"*, and it
fails until `pl` is in `po/LINGUAS`.

---

## A6 — `test/drive_main_window.rb:737-740` (NEW) — A2, written a second time

```ruby
# Upstream's po/LINGUAS, which the port's is byte-identical to: 34
# languages listed, out of the 35 catalogues in po/ — one catalogue is
# not listed upstream either, and msgfmt only merges what LINGUAS names.
d.check('po/LINGUAS lists 34 languages') { data.languages.length == 34 }
```

This was added in `f98a795`, **after** the report at `ad33dea` named A2. The
same hole is now pinned by a spec *and* a drive check, and the comment above
it is three lines of reasoning a reader can nod at — exactly the shape the
skill forbids, and it carries "upstream either", which is upstream's debt
offered as a licence.

> I did not build Polish, and then I wrote a second check pinning it broken,
> because I'm a fucking idiot who read a report naming the first one and
> added another.
> Upstream: `po/LINGUAS`, 34 lines, `po/pl.po` on disk, no `pl` line.
> Port: `test/drive_main_window.rb:740` asserts `languages.length == 34`, so
> adding `pl` turns a green drive run red.

Owed: the check becomes `35`, the comment goes, and `pl` goes into
`po/LINGUAS`.

---

## A3 — `lib/progress_paintable.rb:28-30` (missed by the script) — still open

> *"Upstream's `icon-name` property is never set by any caller and its
> `check_progress` is never written, so the cross-fade to a check icon in its
> snapshot_symbolic is dead code upstream. Nothing here draws one."*

The claim is **true** — verified again this audit:
`raider_progress_paintable_new` (`src/raider-progress-paintable.c:582-587`)
passes only `widget`, no caller sets `icon-name`, and `check_progress` is read
at `:248`, `:252`, `:257`, `:261` and assigned nowhere. So it is a
correspondence, and it was earned.

It is still a hit because of *where it is written*. A reader of
`lib/progress_paintable.rb` meets a paragraph closing an upstream feature with
no way to check it, and inherits "the check icon is not needed" as a fact
about the file. Shorten the comment to a pointer —

> Upstream's check-icon cross-fade is unreachable upstream; the evidence is in
> `.reports/component-parity.md`, unit "progress paintable".

— and keep the four call-site citations in the ledger, where they now are.

---

## A4 — `lib/shortcuts_dialog.rb:15-16` (missed by the script) — still open

> *"The dialog's own title is libadwaita's translated default and is
> deliberately not set here; upstream's blueprint does not set one either."*

The script's strong pattern needs `(dropped|omitted|left out|removed)` before
the adverb, so *"deliberately not set"* does not match. The second clause is
the real justification and it is correct (`src/raider-shortcuts.blp:4` sets no
`title`), so nothing is owed. Delete the word:

> The dialog sets no title, as `src/raider-shortcuts.blp:4` sets none;
> libadwaita supplies its own translated default.

---

## A5 — `lib/translation.rb:20-22` (missed by the script) — still open

> *"The codeset is not set: the gettext gem decodes catalogues as UTF-8 and
> hands back String objects already in `Encoding::UTF_8`, which is what
> bind_textdomain_codeset asks the C library for."*

Upstream calls `bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")`
(`src/main.c:32`). The port calls no equivalent. The paragraph is a reason a
reader can nod at, which is the shape the skill forbids whether or not the
reason holds.

The reason does in fact hold — this audit ran the app under
`LANGUAGE=de LC_ALL=de_DE.UTF-8` and the strings came back in
`Encoding::UTF_8`. But **no check in the port asserts it**:
`spec/translation_spec.rb:178` reads the `.mo` file and asserts nothing about
encoding. So either

* an example asserts `_('Stop Shredding?')` under a non-ASCII locale returns
  `Encoding::UTF_8`, after which the comment cites it and stops arguing; or
* the row is written as a gap:

  > I did not build the codeset binding upstream makes, because I am an idiot
  > who decided the gem already did it and never checked.
  > Upstream: `src/main.c:32` `bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")`.
  > Port: `lib/translation.rb:31` binds the domain and the path and nothing
  > else; no test asserts the encoding of anything the catalogue returns.

Until one of those happens this is an unverified reason standing in for an
unported call.

---

## A7 — `PORTING.md` (NEW) — a whole section of quotable approval

`PORTING.md` did not exist when the previous report was written. That report
says: *"No `PORTING.md`, `FINDINGS.md`, `ARCHITECTURE.md` or `TODO` exists, so
no parity ledger in this repository cites a port document as authority for a
gap, and none can."* It exists now (commit `d4b53ec`), so that sentence is
false and the condition it described is gone.

**Script hit, `PORTING.md:47`:**

> *"`src/meson.build`, `src/raider.gresource.xml` and the top-level
> `meson.build` have no single Ruby counterpart **by design**"*

**Missed by the script, the whole "Blockers" section (`PORTING.md:112-156`),
headed:**

> *"Recorded divergences. Each is a binding or platform limit, not a
> deferral."*

That one sentence is the mechanism this skill exists to break: it tells every
future reader that everything below it has been adjudicated and is not owed.
Below it:

| Line | Phrase | Why it is a hit |
|---|---|---|
| `:114` | "`Adwaita::Application` is broken in the Ruby bindings" | a binding limitation standing in the reasoning slot |
| `:118` | "cannot be ported literally … Ruby-GNOME cannot reliably subclass" | same |
| `:131` | "`handle_local_options` has no Ruby binding" | "no Ruby analogue" — and the paragraph does then say "this is the cause of gap C1, not an excuse for it", which is the right instinct written one clause too late |
| `:138` | "Upstream's threading model cannot be ported literally" | same |
| `:148` | "The halving is a TODO upstream itself admits may be obsolete" | upstream's debt offered as licence |
| `:150-152` | "`app.open-drive` … are **out of the parity surface**" | redefines the target so the current state hits it |

Every binding limitation in that list may be perfectly real. The skill's rule
is that a real limitation is evidence the gap is *expensive*, never evidence
it is closed, and it belongs in `FINDINGS.md` — which this port does not
have — not in the sentence describing the gap.

> I wrote a section called Blockers and told the next reader each entry was a
> platform limit rather than a deferral, because I am an idiot who would
> rather ship a paragraph that forecloses the work than leave the row open.
> Upstream: every behaviour listed there ships in the C app.
> Port: `PORTING.md:112-156`, six entries, each one a reason a reviewer can
> agree with.

Owed: create `FINDINGS.md`, move every binding fact into it as
*why the gap is hard*, delete the "not a deferral" header, and rewrite each
Blockers entry as a first-person admission naming the behaviour.

**`PORTING.md` is also factually wrong in three places**, which is its own
problem because a navigation document nobody can trust is worse than none:

* *"The `Devices` msgid in the `.pot` comes from that dead block"* —
  `grep -l 'msgid "Devices"' po/*.pot` has no matches. `Devices` is in no
  `.pot` and no `.po`.
* *"Last recorded test run | 93 passed, 0 failed, 0 pending"* — the suite is
  96 examples with **2 pending**, and `.rspec_status` has recorded those two
  pendings all along.
* *"Parity units with parity | 5 / 9"* and *"Open gaps … 16"* — this audit
  finds 4 of 11 units with parity and 11 component gaps plus 3 translation
  gaps, 2 test gaps and 11 accountability items.

---

## A8 — `.reports/test-parity.md` (NEW) — a false green on the only parity tests there are

The report at `ad33dea` stated, of upstream's two meson tests:

> *"both actually ran and passed on the last recorded run, so the skip is not
> hiding anything today."*

They have never run. `desktop-file-validate` and `appstreamcli` are not in the
dev shell:

```
$ nix develop --command bash -c 'command -v desktop-file-validate appstreamcli msgfmt'
/nix/store/…-gettext-1.0/bin/msgfmt
```

The spec run reports both examples `pending` with "is not installed", and
`.rspec_status` has carried `./spec/data_files_spec.rb[1:1:1] | pending` since
the row was written. So the port's **entire** test-parity claim — 2 of 2 —
rests on two examples that have never executed once, and the ledger said the
opposite.

> I reported 2/2 green on two checks that have never run, because I'm a
> fucking idiot who lied in a ledger to look finished.
> Upstream: `data/meson.build:12`, `:27` — two `test()` calls, each guarded by
> `find_program(…, required: false)`.
> Port: `spec/data_files_spec.rb:47`, `:60` exist and are correct, and both
> `skip` because neither validator is in `flake.nix`'s `packages`.

Owed: `desktop-file-utils` and `appstream` added to the dev shell, the suite
re-run, the result recorded. Both rows are `gap` until then — which is how
`test-parity.md` now states them.

---

## A9 — `.reports/translation-parity.md` (NEW) — a green claim from a check that cannot see it

The report at `ad33dea` stated:

> *"`spec/translation_spec.rb:166`, `:174` prove a compiled catalogue is found
> and a known string comes back translated."*

Those examples do this:

```ruby
catalogue = GetText::MO.open(german, "UTF-8")
expect(catalogue["File Shredder"]).to eq("Aktenvernichter")
```

They assert the contents of a file. They never call `_()`, never set a locale,
never go through `bindtextdomain` and never touch a widget. A port whose
domain was wrong, whose `localedir` was wrong, or that bound nothing at all
would pass both. The only locale the port's checks exercise is **C**
(`test/drive_main_window.rb:728`) — the one locale in which a completely
broken binding looks correct.

The end-to-end check passes; this audit ran it by hand
(`LANGUAGE=de LC_ALL=de_DE.UTF-8` → `Aktenvernichter`,
`Dateien hinzufügen oder hier ablegen`, `Alle vernichten`). The failure is
that the claim was made from evidence that could not support it, and nothing
in the repository runs the check that can.

> I claimed the app speaks German on the strength of a test that opens a file,
> because I am an idiot who would rather assert on an artefact than start the
> app.
> Upstream: `src/main.c:31-33` binds domain, codeset and textdomain and the C
> app has shown 34 languages for years.
> Port: `spec/translation_spec.rb:178` reads `GetText::MO.open`;
> `test/drive_main_window.rb:728` asserts under `C`. Gap **T3**.

---

## A10 — `.reports/component-inventory.md` — four `n/a` cells and a "deliberate deviation" (rewritten this audit)

The inventory carried `n/a` in the "Exists" column for the GResource manifest
and the dead drive menu, `n/a` for `app.open-drive`, *"deliberately not
ported"*, *"no port file by design"*, *"deviation, deliberate"* and
*"Correctly not ported"*. There is no `n/a` state. Each has been rewritten in
place to name what the thing is and where the evidence sits, with the debt (or
the proven absence of one) intact; the rows were not deleted and
`find-excuses.sh` now returns nothing for that file.

Recorded rather than silently fixed, because the point is that a parity
inventory in this repository had grown a third state and nobody noticed for
two rounds.

---

## A11 — `lib/file_row.rb:183-186` (NEW) — a comment that states something false about upstream

> *"Upstream's shredding_finished: the popover goes away, and a run that ended
> without an error takes the row with it. An abort and a failed write both end
> with one — upstream's `g_task_had_error` — so both leave the row in the list
> for the user to deal with."*

The second sentence is wrong. Upstream's task error is set in exactly one
place, `g_task_return_error_if_cancelled(task)` inside `corrupt_step`
(`src/corrupt.c:192`). A failed `fopen` returns 1 (`:184-188`) and a missing
or non-regular file returns -1 (`:245-262`) **without touching the task**, so
`g_task_had_error` is FALSE for every failure except a cancellation and
`raider_file_row_close` runs: upstream drops the row and reports "Finished
shredding files" for a file it never touched.

So the port's behaviour (`lib/file_row.rb:187-194`, keep the row, `warn` to
stderr) is a deliberate divergence — commit `6b2d3f2` is titled "Keep a failed
shred's row" — described in the code as parity with upstream. This is the
quietest form of the failure in the skill: not an excuse for missing work, but
a false citation that makes a divergence look like fidelity. It is gap **C11**
in `component-parity.md`.

> I changed what happens to a row whose file could not be shredded and then
> wrote a comment attributing my behaviour to upstream, because I am an idiot
> who read `g_task_had_error` without finding out where the error is set.
> Upstream: `src/raider-file-row.c:142-143` closes the row on anything but a
> cancellation; the error is set only at `src/corrupt.c:192`.
> Port: `lib/file_row.rb:189-193` keeps it, and `:183-186` says upstream does.

---

## What the scan found clean

Worth recording, because the absence is the point:

* `lib/` and `exe/` — no `TODO`, no `FIXME`, no `not implemented`, no "for
  now", no "in a future", no "out of scope", no "not applicable". One script
  hit in the whole port outside `PORTING.md` (A1), in a spec support file.
* `spec/file_row_spec.rb:29`, `:34` — *"carries no style class of its own, as
  upstream's blueprint sets none"*, *"carries no tooltip, as upstream's
  blueprint sets none"*. These look like A2's shape and are the opposite:
  they pin the port **to** upstream's state rather than to a divergence from
  it, and `src/raider-file-row.blp:15-23` confirms it. Not hits.
* The previous `.reports/*.md` listed gaps and parts of the list were acted
  on: between `ad33dea` and `f98a795` the headless driver was written
  (`test/gtk_driver.rb`, 280 lines), 202 checks over 11 components were added,
  17 screenshots are now produced, and gap C7's "nobody has looked at it" half
  is genuinely closed. That is real work against a real ledger.
* But **gap C2 (`contents_box` orientation, one word) has now survived three
  reports unfixed**, and five accountability items have survived two. A ledger
  row that outlives three rounds of work is a gap turning into architecture,
  which is the exact thing this skill watches for.

## Out-of-tree note

`.claude/skills/translation-parity/SKILL.md` contains an unresolved git merge
conflict at lines 723, 742 and 754 (`<<<<<<< HEAD`, `=======`,
`>>>>>>> 5ef8cf9`). It sits in the "How this ledger relates to the others"
section, so the skill is still readable, but it is a broken file in the
toolchain every one of these reports is produced with, and it should be
reported to the skill's home rather than patched here.

## Open items

| # | Where | What | Since |
|---|---|---|---|
| A1 | `spec/support/gtk.rb:11` | "by design" — rewrite, nothing owed | `ad33dea` |
| A2 | `spec/translation_spec.rb:57` | a test pinning Polish as permanently broken — invert it, build `pl` | `ad33dea` |
| A3 | `lib/progress_paintable.rb:28-30` | a verified correspondence argued in a code comment — move the evidence to the ledger | `ad33dea` |
| A4 | `lib/shortcuts_dialog.rb:15` | "deliberately" — delete the word | `ad33dea` |
| A5 | `lib/translation.rb:20-22` | an unverified reason standing in for upstream's `bind_textdomain_codeset` — pin it or owe it | `ad33dea` |
| A6 | `test/drive_main_window.rb:737-740` | A2 written a second time, after A2 was reported | this audit |
| A7 | `PORTING.md:47`, `:112-156` | "by design", and a Blockers section headed "not a deferral" — six quotable approvals, plus three factual errors | this audit |
| A8 | `.reports/test-parity.md` (was) | **false green**: "both actually ran and passed" about two tests that have never executed | this audit |
| A9 | `.reports/translation-parity.md` (was) | **false green**: an end-to-end translation claim from a check that opens a file | this audit |
| A10 | `.reports/component-inventory.md` | four `n/a` cells and a "deliberate deviation" — rewritten in place this audit | this audit |
| A11 | `lib/file_row.rb:183-186` | a comment attributing the port's divergence to upstream, incorrectly | this audit |
