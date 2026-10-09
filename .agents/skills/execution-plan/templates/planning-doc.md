<!--
planning-doc.md — committed as the FIRST commit on the FIRST stack layer.
One Layer section per planned PR, in stack order. If a tracker is in use,
layers map 1:1 to its sub-tasks. Delete this comment when filling it in.
-->

# {{work_title}}

> Plan written {{date}}.{{ Parent ticket: [{{parent_id}}]({{parent_url}}).}}

## Goal

{{1–3 sentences: what does shipping this mean for users / the system?}}

## Approach

{{Short narrative of the design decision and alternatives considered. Link to
existing architecture docs instead of re-explaining them. For units with an
INTENT.md, link to its Decisions rows instead of restating them; keep only
delivery choices here (why the cuts fall where they do).}}

## Sketch

{{Omit this section if there is no sketch. Otherwise: link each sketch PNG
(`sketches/<name>.png`), then paste the fat-marker read-back the user
confirmed: parts, connections, constraints, and how each question was
answered. Later sections refer to parts by these names.}}

## Constraints & assumptions

- {{...}}

## Open questions

- [ ] {{question}} — owner: {{name}}

## Stack

Each layer is one branch and one PR. Layer N>1 branches off layer N-1 and
targets it as its PR base.

### Layer 1 — {{layer_1_summary}}

- **Sub-task:** {{layer_1_id or "n/a"}}
- **Branch:** `{{layer_1_branch}}` (off `{{trunk}}`)
- **PR base:** `{{trunk}}`
- **Intent:** {{units whose INTENT.md this layer edits or creates, or "none"}}
- **Sketch parts:** {{sketch parts this layer delivers, by name, or "none"}}
- **Scope:**
  - Planning doc
  - {{bullet}}
- **Done when:**
  - {{acceptance bullet, or the title of a scenario that must pass}}

### Layer 2 — {{layer_2_summary}}

- **Sub-task:** {{layer_2_id or "n/a"}}
- **Branch:** `{{layer_2_branch}}` (off `{{layer_1_branch}}`)
- **PR base:** `{{layer_1_branch}}`
- **Intent:** {{units whose INTENT.md this layer edits or creates, or "none"}}
- **Sketch parts:** {{sketch parts this layer delivers, by name, or "none"}}
- **Scope:**
  - {{bullet}}
- **Done when:**
  - {{acceptance bullet}}

### Layer N — {{layer_n_summary}}

...

## Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| {{risk}} | low / med / high | low / med / high | {{mitigation}} |

## Out of scope

- {{...}} {{Include every sketch part that no layer delivers.}}
