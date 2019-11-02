variable "do_token" {}
variable "ssh_pvt_key" {}
variable "agent_pat" {}
variable "cloudflare_api_token" {}
variable "cloudflare_zone_id" {}

variable "az_subscription_id" {}
variable "az_client_id" {}
variable "az_client_secret" {}
variable "az_tenant_id" {}

variable "gcp_project" {}
variable "gcp_credentials" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

provider "cloudflare" {
  version = "~> 2.0"
  api_token = "${var.cloudflare_api_token}"
}

provider "azurerm" {
    subscription_id = "${var.az_subscription_id}"
    client_id       = "${var.az_client_id}"
    client_secret   = "${var.az_client_secret}"
    tenant_id       = "${var.az_tenant_id}"
}

provider "google" {
  project = "${var.gcp_project}"
  region  = "us-central1"
  zone    = "us-central1-c"
  credentials = "${var.gcp_credentials}"
}