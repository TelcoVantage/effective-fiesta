# Architecture — Dynamic Email Router

## Goal

One inbound email flow that handles **every** mailbox in the org. All routing
decisions live in a **data table**, so onboarding a new email address, domain,
queue, skill set, priority, language or auto-reply is a **data change**, never a
flow change. No republish, no Architect edit, no change window.

## Flow at a glance

```
                       ┌──────────────────────────────────────────────┐
  Inbound Email   ───► │  Inbound Email Route(s)  (Admin > Routing)    │
  (any address)        │  catch-all domain → "Dynamic Email Router"    │
                       └───────────────────────┬──────────────────────┘
                                               │  Email.To.Email
                                               ▼
                       ┌──────────────────────────────────────────────┐
                       │  STATE: Initial State                        │
                       │   • toAddress = lower(trim(Email.To.Email))  │
                       │   • domain    = "@" + host part              │
                       │                                              │
                       │   Tier 1  lookup  toAddress  ───┐            │
                       │   Tier 2  lookup  @domain    ───┤ Email      │
                       │   Tier 3  lookup  DEFAULT    ───┘ Routing DT │
                       └───────────────────────┬──────────────────────┘
                              matched & enabled │ else
                                   ▼            ▼
                       ┌──────────────────┐  ┌────────────────────────┐
                       │ STATE: Route     │  │ STATE: Unrouted        │
                       │  • Auto-reply?   │  │  • Safety-net queue     │
                       │  • Transfer ACD  │  │    ("Email Triage")     │
                       │    queue/skills/ │  │  • else disconnect      │
                       │    priority/lang │  └────────────────────────┘
                       └──────────────────┘
```

## Why three lookup tiers

| Tier | Key example          | Use it for                                            |
|------|----------------------|-------------------------------------------------------|
| 1    | `support@acme.com`   | Per-mailbox behaviour (skills, priority, auto-reply). |
| 2    | `@acme.com`          | Catch a whole tenant/domain with one row.             |
| 3    | `DEFAULT`            | Org-wide safety net so nothing is ever dropped.       |

Most specific wins. A new customer domain is **one** row; a special mailbox that
overrides its domain is **one more** row. The flow logic never changes.

## The control plane: `Email Routing` data table

| Column                  | Type    | Purpose                                                    |
|-------------------------|---------|------------------------------------------------------------|
| `key`                   | string  | Lookup key: address, `@domain`, or `DEFAULT`.              |
| `queueName`             | string  | Target ACD queue.                                          |
| `skills`                | string  | Comma-separated ACD skills, parsed to a list in-flow.      |
| `priority`              | integer | Interaction priority.                                      |
| `languageSkill`         | string  | Language skill applied before transfer.                    |
| `autoReplyEnabled`      | boolean | Send an acknowledgement before queueing.                   |
| `autoReplyResponseName` | string  | Response Management response name (looked up at runtime).  |
| `businessHoursGroup`    | string  | Optional — name of a schedule group for open/closed logic. |
| `screenPopUrl`          | string  | Optional — URL for an agent screen pop.                    |
| `enabled`               | boolean | Turn a route off without deleting the row.                 |

> Data tables are limited to a string **key** plus up to ~9 other columns and
> serve single-row, key-based lookups. That is exactly this design's access
> pattern. If you outgrow it (multi-row queries, >10 attributes, joins), swap
> the in-flow lookups for a **Data Action** hitting an external service or the
> Platform API — the flow's three-tier resolution stays identical.

## Design principles

1. **Separation of logic and configuration.** The flow is pure mechanism;
   the data table is policy. Different people, cadences and change controls.
2. **Fail safe, never fail silent.** Unmatched/disabled/transfer-failure all
   funnel to a triage queue, then disconnect only as a last resort.
3. **Idempotent infrastructure.** Flow + table + rows are all expressed as code
   (Archy YAML + Terraform), so the whole system is reproducible per environment.
4. **Least privilege onboarding.** Adding a mailbox needs data-table edit rights,
   not Architect publish rights.

## Repository layout

```
flows/dynamic-email-router.yaml     Archy inbound email flow (the mechanism)
data-tables/email-routing.schema.json   Data table schema (API create payload)
data-tables/email-routing.sample.csv    Starter routing rules
terraform/                          CX-as-Code: table + rows + flow publish
scripts/deploy-flow.sh              Archy validate/publish helper
scripts/import-datatable.sh         Genesys CLI table create + CSV import
docs/build-guide.md                 Authoritative step-by-step Architect build
docs/extending.md                   Day-2: add/disable mailboxes & domains
```
