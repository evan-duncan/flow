---
name: fat-marker
description: Use when the user wants to draw, sketch, or show how something should look or fit together before planning — "let me sketch it", "fat marker", "breadboard", "here's a drawing", "I'll draw the screen", a photo or screenshot of a whiteboard, paper or tablet sketch — or hands over a .tldr file or a sketch image during planning. Opens a local tldraw canvas, captures the sketch as an image plus a text outline, reads it back for confirmation, and feeds the confirmed sketch into the plan (pairs with execution-plan).
---

# Fat marker sketches

A fat marker sketch is a deliberately coarse drawing of the shape of some
work: a screen, a flow, how components connect. At fat marker width you
can't draw a font or a rounded corner, so you draw only the decisions that
matter: which parts exist, what they are called, what sits inside what,
and what leads to what.

Read a sketch at that fidelity. It fixes **structure and names**. It does
not fix layout, sizes, colors, fonts or copy. Treating it as a pixel spec
wastes effort, and inventing parts it doesn't show defeats its purpose.

Files (paths relative to this skill's directory):

- `app/serve.mjs`: serves the canvas, waits for **Send to agent**, writes
  the sketch, prints its outline and exits. Needs Node 18+.
- `app/index.html`: the canvas: tldraw, loaded from esm.sh at a pinned
  version. It needs network access to load.

## 1. Capture

Put sketches in `sketches/` inside the repo's plan directory
(`docs/plans/sketches/` by default). Name each one with a lowercase slug:
the plan's slug, or `<plan-slug>-<view>` when one plan has several
sketches.

**Draw on the canvas.** Run:

```bash
node <skill-dir>/app/serve.mjs docs/plans/sketches <name>
```

It opens the browser and prints the URL on stderr. It runs until the user
clicks **Send to agent**, so run it in the background if your harness can
do that, and tell the user to draw, label things, and click Send. When it
exits, stdout holds a `# <png path>` line, then the outline. It writes two
files:

- `<name>.png`: what the user drew. Read it: it is the only record of
  freehand ink.
- `<name>.tldr`: the editable sketch. Running the same command again
  reopens it, so the user can revise instead of starting over.

**From an image.** For a photo or screenshot of a paper, whiteboard or
tablet sketch, offer two routes:

- The user drops the image onto the canvas, then labels and connects
  parts on top of it. This is the better route when the handwriting is
  hard to read.
- Read the image directly. Copy it to `docs/plans/sketches/<name>.<ext>`
  and write the outline yourself, in the format below.

## 2. Read the sketch

The outline has one line per mark, numbered in drawing order:

```
frame 1 "Customer statement" at 0,0 760x560
rectangle 2 "customer name + statement date" at 30,30 700x80 in 1
ink 6 at 440,402 335x146 in 1
rectangle 8 "customer list" at -420,40 280x400
arrow 9 from 8 to 2 "click customer"
note 10 "late fee as of statement date, not today" at 749,227 200x200
```

- **Quoted text is the user's words.** Use the labels as names in the
  plan, unchanged. They are the vocabulary of the work.
- **`in N`** means the mark sits inside frame or shape N. Containment is
  structure: a region of a screen, a part of a component.
- **Arrows** go `from` one mark `to` another. A free end shows as
  `(x,y)`. In a screen, an arrow is usually navigation or an action. In a
  system or flow, it is usually data or a dependency. The label says
  which, when there is one.
- **Notes** are constraints or decisions the user wrote down. Carry them
  into the plan as constraints, not as parts to build.
- **Ink** is freehand. The outline gives only where it is. Look at that
  area of the PNG to see what it is: a circle that groups or highlights
  something, a question mark, a strike-through, a scribbled label.
- **Positions and sizes** only locate marks in the PNG and say what is
  near what. Rough order ("header above the table") can matter. Exact
  coordinates never do.
- The numbers change when the sketch is redrawn. Refer to parts by name,
  never by number, in anything that outlives this conversation.

Decide whether the sketch is a **screen** (regions, controls, navigation),
a **flow or system** (components, data, dependencies), or both. Say which;
it changes what the arrows mean.

## 3. Read it back

Before you plan anything, show the user how you read the sketch, and wait
for them to confirm it. A misread sketch produces a confident plan for
the wrong thing. Use this shape:

```
Sketch: <name> (screen | flow | both)

Parts
- <name in the user's words>: what it is and what it holds or does
- ...

Connections
- <part> -> <part>: what the arrow means

Constraints (from notes)
- ...

Questions
- <each ambiguous mark>: what it might mean, and the reading you'd pick
```

- Every labeled part appears under Parts, by its label.
- Ask about every mark you can't read with confidence: unlabeled ink, an
  arrow with no label whose meaning isn't obvious, a box with no text.
  Don't guess silently. A question mark the user drew next to something
  usually means they are unsure it belongs. Ask whether it is in scope.
- Don't add parts the sketch doesn't show. If the work clearly needs one
  (an error state, a loading state, an API between two boxes), list it
  under Questions as "Not in the sketch: …".

When the user corrects you, they can redraw (rerun the command), or you
can apply the correction to your read-back. Either way, show the final
read-back once more before planning with it.

## 4. Hand it to the plan

With the execution-plan skill, the confirmed read-back goes into the
planning doc's **Sketch** section, with a link to the PNG. The PNG and
the `.tldr` are committed with the planning doc as layer 1's first
commit. Then:

- Each layer lists the sketch parts it delivers under **Sketch parts**,
  by name.
- Every part is delivered by some layer or listed under Out of scope.
  None is silently dropped.
- A layer's "Done when" can point at the sketch ("the statement shows
  the four regions in the sketch"). It never asks for pixel fidelity.

Without a planning doc, give the confirmed read-back to whatever comes
next (a brief, a ticket, a prompt) and tell the user where the PNG and
`.tldr` are.

## Changing the app

The tldraw and react versions are pinned in `app/index.html`'s import map.
Bump them together, and only to a version that tldraw's `peerDependencies`
allow. Then:

1. Run `node --test <skill-dir>/app/serve.test.mjs`.
2. Run the server, then draw a box, a labeled arrow between two boxes, a
   note, and a freehand stroke. Click Send. Check the outline lists all
   of them, the arrow names both boxes, and the PNG matches the canvas.
3. Run the server again and check the sketch reopens.
