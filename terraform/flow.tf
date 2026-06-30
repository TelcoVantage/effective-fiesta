# =============================================================================
# Publish the inbound email flow from the Archy YAML. The file_content_hash
# forces a re-publish whenever the YAML changes, and depends_on guarantees the
# data table exists before the flow that references it is published.
# =============================================================================
resource "genesyscloud_flow" "dynamic_email_router" {
  filepath          = "${path.module}/../flows/dynamic-email-router.yaml"
  file_content_hash = filesha256("${path.module}/../flows/dynamic-email-router.yaml")

  depends_on = [
    genesyscloud_architect_datatable.email_routing
  ]
}
