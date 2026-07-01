terraform {
  required_version = ">= 1.5.0"
  required_providers {
    genesyscloud = {
      source  = "mypurecloud/genesyscloud"
      version = ">= 1.40.0"
    }
  }
}

# Credentials are read from the standard environment variables so nothing
# secret is ever committed:
#   GENESYSCLOUD_OAUTHCLIENT_ID
#   GENESYSCLOUD_OAUTHCLIENT_SECRET
#   GENESYSCLOUD_REGION              e.g. us-east-1, eu-west-1, mypurecloud.ie
provider "genesyscloud" {
  # Values intentionally omitted - sourced from environment.
}

# Resolve the Home division so the data table + flow land in a known division.
data "genesyscloud_auth_division_home" "home" {}
