# Extending — Day-2 operations

Everything below is a **data** change. The flow is never touched.

## Add a new mailbox (most common)

Add one row to the `Email Routing` data table.

**UI:** Admin ▸ Architect ▸ Data Tables ▸ *Email Routing* ▸ **Add Row**.

| Field                   | Example                          |
|-------------------------|----------------------------------|
| key                     | `returns@acme.com`               |
| queueName               | `Acme Returns`                   |
| skills                  | `Returns,Tier1 Support`          |
| priority                | `2`                              |
| languageSkill           | `English - Written`              |
| autoReplyEnabled        | `true`                           |
| autoReplyResponseName   | `Returns Acknowledgement`        |
| enabled                 | `true`                           |

That's it — the next email to that address routes by the new row. No publish.

**Terraform:** add a block under `email_routing_rows` in `terraform.tfvars`:

```hcl
"returns@acme.com" = {
  queueName             = "Acme Returns"
  skills                = "Returns,Tier1 Support"
  priority              = 2
  languageSkill         = "English - Written"
  autoReplyEnabled      = true
  autoReplyResponseName = "Returns Acknowledgement"
}
```

```bash
cd terraform && terraform apply
```

## Onboard a whole new domain

Add a single `@domain` row (Tier 2). Every address on that domain that has no
exact row inherits it:

```
key=@globex.com  queueName=Globex Care  priority=1  autoReplyEnabled=true ...
```

## Temporarily disable a route

Set `enabled=false` on the row. The flow sends it to the safety-net triage queue
instead. Re-enable by flipping it back — no row deletion, full audit trail.

## Change where existing mail goes

Edit `queueName` / `skills` / `priority` on the row. Takes effect on the next
interaction. Great for surge handling, seasonal teams, or moving a product line
to a new queue.

## Add a new language

1. Create the language skill (e.g. `German - Written`) and a German Response
   Management response.
2. Set `languageSkill=German - Written` and the German
   `autoReplyResponseName` on the relevant rows.

## Prerequisites checklist when adding a row

Before a new row goes live, make sure the things it references exist:

- [ ] `queueName` is a real ACD queue.
- [ ] every skill in `skills` exists as an ACD skill.
- [ ] `languageSkill` exists (if set).
- [ ] `autoReplyResponseName` exists in the `Email Routing Auto Replies`
      library with an **email** body (if `autoReplyEnabled=true`).
- [ ] the inbound address/domain is covered by an **Inbound Email Route**
      pointing at *Dynamic Email Router*.

## Governance tips

- **Keep `DEFAULT` permanent.** It is the guarantee that no email is ever lost.
- **Manage rows in Terraform for prod**, UI for quick triage in lower envs —
  but pick one system of record per environment to avoid drift.
- **Use `enabled` instead of deleting** so you keep history and can revert fast.
- **Lowercase keys.** The flow lowercases the recipient before lookup, so keys
  must be lowercase to match.
