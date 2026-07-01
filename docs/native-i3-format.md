# The native `.i3InboundEmailFlow` format

Architect's **Export** produces a native flow file (`.i3InboundEmailFlow`,
`.i3InboundCallFlow`, `.i3BotFlow`, …). This repo reverse-engineered the
container so you can decode, inspect, edit and re-encode it.

## Container format (verified)

```
file bytes  =  base64( urlencode( JSON ) )
```

`scripts/i3flow.py` implements exactly this and its round-trip was verified
byte-for-byte against Genesys's own published sample export:

```bash
python3 scripts/i3flow.py decode  flows/dynamic-email-router.i3InboundEmailFlow  out.json
python3 scripts/i3flow.py encode  out.json  flows/dynamic-email-router.i3InboundEmailFlow
python3 scripts/i3flow.py verify  flows/dynamic-email-router.i3InboundEmailFlow   # -> round-trip: OK
```

## The inner JSON is a *compiled* model

Top-level keys for an inbound email flow: `type` (`"inboundemail"`), `name`,
`defaultLanguage`, `initialSequence`, `startUpRef`-equivalent, `manifest`
(external dependency references — queues, data actions, in-queue flows, prompts),
`uiMetaData`, `inboundEmailSettings`, `errorHandling`, `variables`, and
`flowSequenceItemList` (the states → `actionList` graph).

Crucially, **every expression is stored as a compiled AST**, not source text.
For example `FindQueue("Email Triage")` compiles to:

```json
{
  "config": {"FindQueue": {"pos": 1, "text": "FindQueue(\"Email Triage\")",
    "operands": [{"lit": {"pos": 11, "text": "Email Triage", "type": "str"}}],
    "type": "que"}},
  "text": "FindQueue(\"Email Triage\")", "type": "que",
  "uiMetaData": {"mode": 0}, "metaData": {}, "version": 2
}
```

Each node carries character offsets (`pos`), inferred type tags (`str`, `int`,
`bln`, `que`, `usr`, `lac`, …), operand trees, and `metaData.references` binding
variable **UUIDs**. Architect validates all of this on import.

## Why the full logic ships as YAML, not native

Nested expressions like `ToLower(Trim(Email.Message.to[0].id))` or a Data Table
Lookup with several output bindings would each require a hand-built, internally
consistent AST (correct offsets, type inference, UUID bindings). That is a
**compiler's** job — hand-authoring it is error-prone and unsupported.

Therefore:

- **`flows/dynamic-email-router.yaml`** — the full, data-table-driven flow.
  Architect's UI **Save ▸ Import** accepts `.yaml`, and `archy create` compiles
  the expressions server-side. **This is the recommended import.**
- **`flows/dynamic-email-router.i3InboundEmailFlow`** — a native-format,
  import-ready **minimal shell**: a single Initial State with a Disconnect and
  **zero external dependencies**, produced by stripping Genesys's own verified
  email-flow export down to schema-correct scaffolding. Import it to get a native
  shell in the correct format, then either layer the data-table lookups per
  `docs/build-guide.md`, or (recommended) just import the YAML instead.

  > Why only a Disconnect, not a Transfer? A compiled **Transfer to ACD** action
  > carries version-sensitive in-queue-handling fields (`useDefaultHandling`,
  > `inQueueFlowId`, …) whose exact valid representation depends on how Architect
  > compiled it. Hand-editing those beyond a trivial shell risks a *“flow import
  > failed / failed to load the flow”* error. Anything past the shell should be
  > compiled by Architect/Archy from the **YAML**, not hand-authored in the
  > native model.
- **`flows/dynamic-email-router.i3flow.json`** — the decoded, human-readable
  model behind the native file; edit it and run `i3flow.py encode` to regenerate.

## Editing the native file safely

Good, low-risk edits to the decoded JSON: renaming the flow, changing a literal
queue name inside an existing `FindQueue("…")` (the token offsets are unchanged
when the prefix length is unchanged), toggling literal booleans/integers.

Risky edits (let Archy/Architect compile instead): adding actions, writing new
expressions, changing expression structure, or anything that shifts `pos`
offsets or introduces new variable references.
