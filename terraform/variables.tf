variable "email_routing_rows" {
  description = <<-EOT
    Map of Email Routing data table rows. The map KEY is the lookup key the flow
    matches against: an exact lowercased address (support@acme.com), an @domain
    fallback (@acme.com), or the literal DEFAULT sentinel (org-wide safety net).
    Add an entry to onboard a new mailbox - no flow change required.
  EOT
  type = map(object({
    queueName             = string
    skills                = optional(string, "")
    priority              = optional(number, 0)
    languageSkill         = optional(string, "")
    autoReplyEnabled      = optional(bool, false)
    autoReplyResponseName = optional(string, "")
    businessHoursGroup    = optional(string, "")
    screenPopUrl          = optional(string, "")
    enabled               = optional(bool, true)
  }))

  # Sensible starter set mirroring data-tables/email-routing.sample.csv.
  default = {
    "DEFAULT" = {
      queueName             = "Email Triage"
      autoReplyEnabled      = true
      autoReplyResponseName = "Generic Acknowledgement"
    }
    "@acme.com" = {
      queueName             = "Acme Customer Care"
      priority              = 1
      languageSkill         = "English - Written"
      autoReplyEnabled      = true
      autoReplyResponseName = "Acme Acknowledgement"
      businessHoursGroup    = "Acme Hours"
    }
    "support@acme.com" = {
      queueName             = "Acme Support"
      skills                = "Tier1 Support"
      priority              = 2
      languageSkill         = "English - Written"
      autoReplyEnabled      = true
      autoReplyResponseName = "Support Acknowledgement"
      businessHoursGroup    = "Acme Hours"
    }
  }
}
