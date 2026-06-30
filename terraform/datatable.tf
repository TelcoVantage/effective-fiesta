# =============================================================================
# Email Routing data table  —  the single control plane for the email flow.
# =============================================================================
resource "genesyscloud_architect_datatable" "email_routing" {
  name        = "Email Routing"
  division_id = data.genesyscloud_auth_division_home.home.id
  description = "Drives the 'Dynamic Email Router' inbound email flow. One row per inbound recipient (exact address, @domain fallback, or the DEFAULT sentinel)."

  # The FIRST property block is always the table key.
  properties {
    name  = "key"
    type  = "string"
    title = "Email Address / Domain / DEFAULT"
  }
  properties {
    name  = "queueName"
    type  = "string"
    title = "Queue Name"
  }
  properties {
    name  = "skills"
    type  = "string"
    title = "ACD Skills (comma separated)"
  }
  properties {
    name    = "priority"
    type    = "integer"
    title   = "Interaction Priority"
    default = "0"
  }
  properties {
    name  = "languageSkill"
    type  = "string"
    title = "Language Skill"
  }
  properties {
    name    = "autoReplyEnabled"
    type    = "boolean"
    title   = "Auto Reply Enabled"
    default = "false"
  }
  properties {
    name  = "autoReplyResponseName"
    type  = "string"
    title = "Auto Reply Response Name"
  }
  properties {
    name  = "businessHoursGroup"
    type  = "string"
    title = "Business Hours Group (optional)"
  }
  properties {
    name  = "screenPopUrl"
    type  = "string"
    title = "Screen Pop URL (optional)"
  }
  properties {
    name    = "enabled"
    type    = "boolean"
    title   = "Enabled"
    default = "true"
  }
}

# -----------------------------------------------------------------------------
# Rows are data-driven from a local map so onboarding a new mailbox is a
# one-line edit in terraform.tfvars (or load them from CSV out-of-band - see
# scripts/import-datatable.sh). Each map entry == one routing rule.
# -----------------------------------------------------------------------------
resource "genesyscloud_architect_datatable_row" "rows" {
  for_each     = var.email_routing_rows
  datatable_id = genesyscloud_architect_datatable.email_routing.id
  key_value    = each.key

  properties_json = jsonencode({
    queueName             = each.value.queueName
    skills                = each.value.skills
    priority              = each.value.priority
    languageSkill         = each.value.languageSkill
    autoReplyEnabled      = each.value.autoReplyEnabled
    autoReplyResponseName = each.value.autoReplyResponseName
    businessHoursGroup    = each.value.businessHoursGroup
    screenPopUrl          = each.value.screenPopUrl
    enabled               = each.value.enabled
  })
}
