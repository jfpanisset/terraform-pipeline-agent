variable "ssh_pvt_key" {}
variable "agent_pat" {}
variable "cloudflare_api_token" {}
variable "cloudflare_zone_id" {}

variable "gcp_project" {}
variable "gcp_credentials" {}

provider "cloudflare" {
  version = "~> 2.0"
  api_token = "${var.cloudflare_api_token}"
}

provider "google" {
  project = "${var.gcp_project}"
  region  = "us-central1"
  zone    = "us-central1-c"
  credentials = "${var.gcp_credentials}"
}