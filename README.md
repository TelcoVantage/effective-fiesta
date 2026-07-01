# Dynamic Email Router — Genesys Cloud

A **data-table-driven inbound email flow** for Genesys Cloud. One catch-all flow
handles every mailbox in the org; all routing behaviour — queue, skills,
priority, language, auto-reply — is resolved **at runtime from a data table**.

**Onboarding a new email address is a single data-table row. The flow is never
edited or republished.**

```
support@acme.com ─┐
billing@acme.com ─┤                                  ┌─ Email Routing data table ─┐
sales@acme.com   ─┼─► Dynamic Email Router flow ────►│ key → queue/skills/priority │
@globex.com      ─┤        (3-tier lookup)           │       /language/auto-reply  │
anything-else    ─┘                                  └─────────────────────────────┘
```

## Why this design

- **Add a mailbox without a change window.** New address/domain = one row. No
  Architect edit, no publish, no deploy.
- **Most-specific-wins routing.** Exact address → `@domain` → `DEFAULT`, so you
  can be as broad or as surgical as you like.
- **Fail safe, never fail silent.** Unmatched, disabled, or failed transfers all
  funnel to a triage queue before any disconnect.
- **Everything as code.** Flow (Archy YAML) + data table + rows (Terraform) are
  reproducible per environment.

## What's in here

| Path                                   | What it is                                            |
|----------------------------------------|-------------------------------------------------------|
| `flows/dynamic-email-router.yaml`      | The inbound email flow (Archy YAML) — full logic.     |
| `flows/dynamic-email-router.i3InboundEmailFlow` | Native Architect import file (starter shell).|
| `flows/dynamic-email-router.i3flow.json`| Decoded, human-readable native model.                |
| `scripts/i3flow.py`                    | Codec for native `.i3*Flow` files (decode/encode/verify). |
| `docs/architecture-diagram.svg` / `docs/flow-diagram.mmd` | Visual diagrams.                   |
| `docs/native-i3-format.md`             | The reverse-engineered `.i3*Flow` format, explained.  |
| `data-tables/email-routing.schema.json`| Data table schema (API create payload).               |
| `data-tables/email-routing.sample.csv` | Starter routing rules.                                |
| `terraform/`                           | CX-as-Code: data table + rows + flow publish.         |
| `scripts/deploy-flow.sh`               | Archy validate/publish helper.                        |
| `scripts/import-datatable.sh`          | Genesys CLI table create + CSV import.                |
| `docs/architecture.md`                 | How and why it works.                                 |
| `docs/build-guide.md`                  | **Authoritative** step-by-step Architect build.       |
| `docs/extending.md`                    | Day-2: add / disable / re-route mailboxes.            |

## Quick start

### Option A — Terraform (recommended for real environments)

```bash
export GENESYSCLOUD_OAUTHCLIENT_ID=...        # Implicit/Client-Credentials OAuth client
export GENESYSCLOUD_OAUTHCLIENT_SECRET=...
export GENESYSCLOUD_REGION=us-east-1          # your region

cd terraform
cp terraform.tfvars.example terraform.tfvars  # edit your routing rows
terraform init
terraform apply
```

Creates the `Email Routing` data table, loads your rows, and publishes the flow.

### Option B — CLI / Archy

```bash
# 1) Create the data table and load the sample rows
./scripts/import-datatable.sh

# 2) Validate and publish the flow
./scripts/deploy-flow.sh
```

### Then, in the Genesys Cloud UI

1. Ensure the referenced **queues**, **skills**, **language skills** and the
   **Response Management** library `Email Routing Auto Replies` exist
   (see `docs/build-guide.md` ▸ Prerequisites).
2. Admin ▸ Routing ▸ **Email** ▸ your inbound route ▸ set **Flow = Dynamic Email
   Router** (use a catch-all domain to funnel many addresses into the one flow).
3. Send a test email and confirm routing (see the test matrix in the build guide).

## Add a new email address later

Add a row to the `Email Routing` data table (UI, CLI, or Terraform) — done.
Full walkthrough in [`docs/extending.md`](docs/extending.md).

## Notes & assumptions

- Lookup key is the **lowercased** recipient `Email.Message.to[0].id` — the
  verified inbound-email built-in (confirmed against Genesys's own email flow
  export), used in `flows/dynamic-email-router.yaml` and `docs/build-guide.md`.
- Archy's YAML keys vary slightly by CLI version; if `archy validate` flags
  something, `docs/build-guide.md` is the source of truth (kept 1:1 with the YAML).

## Two ways to import into Architect

| Artifact | How to import | Carries |
|----------|---------------|---------|
| `flows/dynamic-email-router.yaml` | Architect UI **Save ▸ Import** (accepts `.yaml`), or `archy create` | **Full** data-table logic (recommended) |
| `flows/dynamic-email-router.i3InboundEmailFlow` | Architect UI **Save ▸ Import** | Native-format **minimal valid shell** (Initial State ▸ Disconnect) |

The `.i3InboundEmailFlow` file is Architect's native export format, which this
repo's `scripts/i3flow.py` codec proved to be `base64(urlencode(compiled-JSON))`
— a compiler artifact whose expressions are stored as compiled ASTs. Because
non-trivial expressions cannot be reliably hand-authored in that form, the full
data-table routing lives in the **YAML** (also UI-importable); the native file is
a minimal, import-ready email-flow shell (Initial State ▸ Disconnect, zero
external dependencies) you extend in Architect. See `docs/native-i3-format.md`.
- Data tables suit single-row, key-based lookups (string key + up to ~9 columns).
  To exceed that, swap the in-flow lookups for a **Data Action** — the flow's
  three-tier logic is unchanged. See `docs/architecture.md`.
