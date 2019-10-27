resource "digitalocean_droplet" "agent" {
    image = "ubuntu-18-04-x64"
    name = "punty.gervas.io"
    region = "sfo2"
    size = "s-4vcpu-8gb"
    ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
    user_data = "${file("user_data.yml")}"

  connection {
      user = "agent"
      type = "ssh"
      private_key = "${var.ssh_pvt_key}"
      timeout = "2m"
      host = "${digitalocean_droplet.agent.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      "sh /wait-for-cloud-init.sh",
      "cd agent",
      "export VSTS_AGENT_INPUT_URL=https://dev.azure.com/g3rv4",
      "export VSTS_AGENT_INPUT_AUTH=pat",
      "export VSTS_AGENT_INPUT_TOKEN=${var.agent_pat}",
      "export VSTS_AGENT_INPUT_POOL=default",
      "export VSTS_AGENT_INPUT_AGENT=punty",
      "./config.sh --unattended --acceptTeeEula --replace",
      "sudo ./svc.sh install",
      "sudo ./svc.sh start",
    ]
  }

  provisioner "remote-exec" {
    when   = "destroy"
    on_failure = "continue"
    inline = [
      "sudo -H -i -u agent bash << EOF",
      "cd ~/agent",
      "export VSTS_AGENT_INPUT_URL=https://dev.azure.com/g3rv4",
      "export VSTS_AGENT_INPUT_AUTH=pat",
      "export VSTS_AGENT_INPUT_TOKEN=${var.agent_pat}",
      "export VSTS_AGENT_INPUT_POOL=default",
      "export VSTS_AGENT_INPUT_AGENT=punty",
      "sudo ./svc.sh stop",
      "EOF"
    ]
  }
}

resource "cloudflare_record" "agent" {
  zone_id = "${var.cloudflare_zone_id}"
  name    = "punty"
  value   = "${digitalocean_droplet.agent.ipv4_address}"
  type    = "A"
  ttl     = 120
}