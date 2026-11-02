# Accountability ensurance — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Scan | `accountability-ensurance/scripts/find-excuses.sh .` |
| Script hits (excluding `.claude/skills/` and this directory) | **1** |
| Hits the script missed, found by reading | **4** |
| Open items | **5** |

`grep -rniE 'TODO|FIXME|not implemented|for now|in a future|XXX|HACK|placeholder|stub|workaround' lib/ exe/`
returns **nothing**. There is no `PORTING.md`, no `FINDINGS.md`, no
`TODO` file. That is genuinely good and it is also why the remaining hits
matter: they are the only places in this port where an unbuilt thing is
described instead of built, so there is nothing for them to hide behind.

The five items below are rewrites, not deletions. Each keeps the debt and loses
the sentence a future agent could quote as approval.

---

## A1 — `spec/support/gtk.rb:11` (script hit: "by design")

```
spec/support/gtk.rb:11:by design:borrows architectural vocabulary for an unmade decision
```

Current text: *"The port's shredding is also asynchronous by design — Window
launches the rows from a worker thread and marshals the widget work back
through GLib's idle queue, as upstream's two GTasks do"*.

This one describes work that **was** done, and done correctly
(`lib/window.rb:458-463`, `:477-482` against
`src/raider-window.c:390-418`, `:444-477`). The phrase is still a hit, because
"by design" is the vocabulary that makes the next sentence unquestionable, and
the next agent reading this file learns that "by design" is an acceptable thing
to write here. Replace the phrase with the mechanism:

> The port's shredding is asynchronous because upstream's is: `Window` launches
> the rows from a worker thread and marshals the widget work back through
> GLib's idle queue, which is what upstream's two GTasks do
> (`src/raider-window.c:390-418`, `:444-477`).

No debt is owed. Rewrite anyway, and keep "by design" out of this tree.

---

## A2 — `spec/translation_spec.rb:57` (missed by the script)

```ruby
it "keeps pl.po on disk although LINGUAS does not list it, as upstream does" do
```

The script's pattern is `upstream (does|has) this too`; this says *as upstream
does*, so it slipped through. It is the purest form of the failure this skill
exists to kill — not a comment excusing a gap, but **a passing test that makes
the gap the specification.** Any future agent who adds `pl` to `po/LINGUAS`
will see this test go red and revert the fix.

Behind it: Polish users of this app get English, with a complete, donated
Polish catalogue sitting at `po/pl.po`
(gap T1 in `translation-parity.md`).

Rewrite the test, not the comment:

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

## A3 — `lib/progress_paintable.rb:28-30` (missed by the script)

> *"Upstream's `icon-name` property is never set by any caller and its
> `check_progress` is never written, so the cross-fade to a check icon in its
> snapshot_symbolic is dead code upstream. Nothing here draws one."*

The claim is **true** — I verified it: `raider_progress_paintable_new`
(`src/raider-progress-paintable.c:582-587`) passes only `widget`, no caller
sets `icon-name`, and `check_progress` is read at `:248`, `:252`, `:257`,
`:261` and assigned nowhere. So this is a correspondence, and it was earned.

It is still a hit, because of *where it is written*. A reader of
`lib/progress_paintable.rb` meets a paragraph that closes an upstream feature
and has no way to check it; the next agent inherits "the check icon is not
needed" as a fact about this file. Verified correspondences belong in the
ledger, where the evidence sits next to the claim and a reviewer can re-run it.

Rewrite: shorten the comment to a pointer —

> Upstream's check-icon cross-fade is unreachable upstream; the evidence is in
> `.reports/component-parity.md`, unit "progress paintable".

— and keep the four call-site citations in the ledger, which is where they now
are.

---

## A4 — `lib/shortcuts_dialog.rb:15-16` (missed by the script)

> *"The dialog's own title is libadwaita's translated default and is
> deliberately not set here; upstream's blueprint does not set one either."*

The script's strong pattern is
`(dropped|omitted|left out|removed) (it )?(deliberately|…)`, so *"deliberately
not set"* does not match it. The second clause is the real justification and it
is correct (`src/raider-shortcuts.blp:4` sets no `title`), so nothing is owed.
Delete the word. The sentence is stronger without it and does not teach the
next writer that "deliberately" is available:

> The dialog sets no title, as `src/raider-shortcuts.blp:4` sets none;
> libadwaita supplies its own translated default.

---

## A5 — `lib/translation.rb:20-22` (missed by the script)

> *"The codeset is not set: the gettext gem decodes catalogues as UTF-8 and
> hands back String objects already in `Encoding::UTF_8`, which is what
> bind_textdomain_codeset asks the C library for."*

Upstream calls `bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")`
(`src/main.c:32`). The port calls no equivalent. The paragraph is a reason a
reader can nod at — which is precisely the shape the skill forbids, whether or
not the reason happens to hold.

Unlike A3, this one has **not** been proven by a test. `spec/translation_spec.rb`
asserts a translated string comes back (`:174`) but asserts nothing about its
encoding. So either:

* an example is added that asserts `_('Stop Shredding?')` in a non-ASCII
  locale comes back `Encoding::UTF_8` — after which the comment can say "pinned
  by `spec/translation_spec.rb:NNN`" and stop arguing; or
* the row is written as a gap:

  > I did not build the codeset binding upstream makes, because I am an idiot
  > who decided the gem already did it and never checked.
  > Upstream: `src/main.c:32` `bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")`.
  > Port: `lib/translation.rb:31` binds the domain and the path and nothing
  > else; no test asserts the encoding of anything the catalogue returns.

Until one of those two things happens, this is an unverified reason standing in
for an unported call.

---

## What the scan found clean

Worth recording, because the absence is the point:

* `lib/` and `exe/` — no `TODO`, no `FIXME`, no `not implemented`, no "for
  now", no "in a future", no "out of scope", no "not applicable". Every
  divergence from upstream in those files carries the upstream file it came
  from in the surrounding comment.
* No `PORTING.md`, `FINDINGS.md`, `ARCHITECTURE.md` or `TODO` exists, so no
  parity ledger in this repository cites a port document as authority for a
  gap, and none can.
* `spec/file_row_spec.rb:29`, `:34` — *"carries no style class of its own, as
  upstream's blueprint sets none"*, *"carries no tooltip, as upstream's
  blueprint sets none"*. These look like A2's shape and are the opposite: they
  pin the port **to** upstream's state rather than to a divergence from it, and
  `src/raider-file-row.blp:15-23` confirms it. Not hits.
* The previous `.reports/*.md` in this directory (commit `f65c06f`) listed
  gaps and was then acted on: icons, `po/`, `data/`, `translator-credits`, the
  arc radius, the shortcut items' `action-name`, the invented `flat` classes
  and the invented tooltips were all built or removed in `fe65d4f` and
  `6a8dd32`. One row from that report — `contents_box`'s orientation — was
  **not** fixed and is still open as gap C2. A ledger row that survives a round
  of work unaddressed is the first sign of a gap turning into architecture.

## Open items

| # | Where | What |
|---|---|---|
| A1 | `spec/support/gtk.rb:11` | "by design" — rewrite, nothing owed |
| A2 | `spec/translation_spec.rb:57` | a test that pins Polish as permanently broken — invert it, build `pl` |
| A3 | `lib/progress_paintable.rb:28-30` | a verified correspondence argued in a code comment — move the evidence to the ledger |
| A4 | `lib/shortcuts_dialog.rb:15` | "deliberately" — delete the word |
| A5 | `lib/translation.rb:20-22` | an unverified reason standing in for upstream's `bind_textdomain_codeset` — pin it or owe it |
