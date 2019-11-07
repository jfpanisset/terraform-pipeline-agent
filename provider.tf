variable "agent_name" {}
variable "pipelines_agent_pat" {}
variable "pipelines_provisioner_pat" {}
variable "pipelines_org" {}
variable "pipelines_pool_id" {}
variable "pipelines_pool_name" {}

variable "terraform_workspace" {}
variable "terraform_token" {}

variable "ssh_pvt_key_base64" {}
variable "cloudflare_api_token" {}
variable "cloudflare_zone_id" {}

variable "gcp_project" {}
variable "gcp_zone" {}
variable "gcp_machine_type" {}

variable "gcp_credentials_base64" {}

provider "cloudflare" {
  version = "~> 2.0"
  api_token = "${var.cloudflare_api_token}"
}

provider "google" {
  project = "${var.gcp_project}"
  region  = "us-central1"
  zone    = "us-central1-c"
  credentials = "${base64decode(var.gcp_credentials_base64)}"
}