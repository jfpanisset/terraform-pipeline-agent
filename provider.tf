variable "do_token" {}
variable "ssh_pvt_key" {}
variable "ssh_fingerprint" {}
variable "agent_pat" {}
variable "cloudflare_api_token" {}
variable "cloudflare_zone_id" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

provider "cloudflare" {
  version = "~> 2.0"
  api_token = "${var.cloudflare_api_token}"
}