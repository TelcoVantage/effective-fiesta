output "email_routing_datatable_id" {
  description = "ID of the Email Routing data table."
  value       = genesyscloud_architect_datatable.email_routing.id
}

output "dynamic_email_router_flow_id" {
  description = "ID of the published Dynamic Email Router inbound email flow."
  value       = genesyscloud_flow.dynamic_email_router.id
}

output "row_count" {
  description = "Number of routing rules currently managed by Terraform."
  value       = length(genesyscloud_architect_datatable_row.rows)
}
