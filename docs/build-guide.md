# Build Guide — Dynamic Email Router (authoritative)

This is the step-by-step Architect build that `flows/dynamic-email-router.yaml`
encodes. Because Archy's YAML keys drift slightly between CLI versions, **this
guide is the source of truth** — if `archy validate` complains, build/repair in
the UI from these steps and re-export.

## Prerequisites

1. **Data table** `Email Routing` created (see `docs/extending.md` or run
   `scripts/import-datatable.sh`).
2. **Queues** referenced by your rows exist (e.g. `Email Triage`,
   `Acme Support`).
3. **ACD skills / language skills** referenced by your rows exist.
4. **Response Management** library `Email Routing Auto Replies` with the response
   names you reference (e.g. `Generic Acknowledgement`). Each response needs an
   **email** body type.
5. An **Inbound Email Route** (Admin ▸ Routing ▸ Email) whose domain/addresses
   point at this flow. Use a catch-all domain to funnel many addresses into the
   one flow.

## Flow type & variables

Create **Architect ▸ Flows ▸ Inbound Email ▸ New Flow** → *Dynamic Email Router*.

Add these flow variables:

| Variable                     | Type    | Default        |
|------------------------------|---------|----------------|
| `Flow.toAddress`             | String  | (none)         |
| `Flow.domain`                | String  | (none)         |
| `Flow.matched`               | Boolean | `false`        |
| `Flow.queueName`             | String  | `__UNROUTED__` |
| `Flow.skills`                | String  | (none)         |
| `Flow.priority`              | Integer | `0`            |
| `Flow.languageSkill`         | String  | (none)         |
| `Flow.autoReplyEnabled`      | Boolean | `false`        |
| `Flow.autoReplyResponseName` | String  | (none)         |
| `Flow.rowEnabled`            | Boolean | `true`         |

## State 1 — Initial State

1. **Update Data** — "Normalise Recipient":
   - `Flow.toAddress` = `ToLower(Trim(Email.To.Email))`
     *(If your org surfaces `Email.To` as a collection, use `Email.To[1].Email`.)*
   - `Flow.domain` =
     `If(Find(Flow.toAddress, "@") >= 0, Substring(Flow.toAddress, Find(Flow.toAddress, "@")), "@__nodomain__")`

2. **Data Table Lookup** — "Lookup Exact Address":
   - Data table: `Email Routing`; Lookup key: `Flow.toAddress`.
   - Map each output column to its `Flow.*` variable.
   - **No-match defaults:** `queueName` → `__UNROUTED__`, `priority` → `0`,
     `enabled` → `true`, the rest → NOT_SET.

3. **Decision** — "Matched Exact?": condition `Flow.queueName != "__UNROUTED__"`.
   - **Yes:** Update Data `Flow.matched = true`.
   - **No:** **Data Table Lookup** "Lookup Domain" (key `Flow.domain`, same
     output mapping & defaults), then **Decision** "Matched Domain?"
     (`Flow.queueName != "__UNROUTED__"`):
     - **Yes:** `Flow.matched = true`.
     - **No:** **Data Table Lookup** "Lookup Default" (key literal `DEFAULT`),
       then Update Data `Flow.matched = (Flow.queueName != "__UNROUTED__")`.

4. **Decision** — "Routable?": `Flow.matched == true and Flow.rowEnabled == true`.
   - **Yes:** Change state → **Route**.
   - **No:** Change state → **Unrouted**.

## State 2 — Route

1. **Decision** — "Send Auto Reply?":
   `Flow.autoReplyEnabled == true and IsNotSetOrEmpty(Flow.autoReplyResponseName) == false`.
   - **Yes:** **Send Auto Reply** using Response Management library
     `Email Routing Auto Replies`, response `Flow.autoReplyResponseName`.
   - **No:** nothing.

2. **Transfer to ACD** — "Transfer To Resolved Queue":
   - Queue: `Flow.queueName`
   - Skills: `If(IsNotSetOrEmpty(Flow.skills), MakeList(), Split(Flow.skills, ","))`
   - Language skill: `Flow.languageSkill`
   - Priority: `Flow.priority`
   - **Failure path:** Change state → **Unrouted**.

## State 3 — Unrouted (safety net)

1. **Transfer to ACD** — "Safety Net Queue": queue `Email Triage`, priority `0`.
   - **Failure path:** **Disconnect**.

## Validate, publish, wire up

```bash
./scripts/deploy-flow.sh validate     # archy validate
./scripts/deploy-flow.sh              # archy create/replace
```

Then Admin ▸ Routing ▸ Email ▸ your inbound route ▸ set **Flow = Dynamic Email
Router**. Send a test email to a `key` you added and confirm it lands on the
expected queue with the expected skills/priority and (if enabled) an
acknowledgement.

## Test matrix

| Send to                 | Expected outcome                                          |
|-------------------------|----------------------------------------------------------|
| `support@acme.com`      | Tier 1 row → Acme Support, Tier1 Support skill, prio 2.   |
| `random@acme.com`       | No exact row → Tier 2 `@acme.com` → Acme Customer Care.   |
| `hello@unknown.com`     | No exact/domain row → Tier 3 `DEFAULT` → Email Triage.    |
| `oldteam@acme.com`      | Row exists but `enabled=false` → Unrouted → Email Triage. |
