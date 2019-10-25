resource "digitalocean_droplet" "agent" {
    image = "ubuntu-18-04-x64"
    name = "punty.gervas.io"
    region = "sfo2"
    size = "s-4vcpu-8gb"
    ssh_keys = [
      "${var.ssh_fingerprint}"
    ]

  connection {
      user = "root"
      type = "ssh"
      private_key = "${var.ssh_pvt_key}"
      timeout = "2m"
      host = "${digitalocean_droplet.agent.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      # create the agent user
      "adduser --disabled-password --gecos \"\" agent",
      "usermod -aG sudo agent",
      "echo 'agent ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo",

      # run all of what's next as the 'agent' user
      "sudo -H -i -u agent bash << EOF",
      "cd ~",

      # install powershell
      "wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb",
      "sudo dpkg -i packages-microsoft-prod.deb",
      "sudo apt-get update",
      "sudo add-apt-repository universe",
      "sudo apt-get install -y powershell",

      # install docker
      "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable\"",
      "sudo apt update",
      "sudo apt install -y docker-ce",
      "sudo usermod -aG docker agent",

      # install and start the pipelines agent
      "mkdir agent",
      "cd agent",
      "wget https://vstsagentpackage.azureedge.net/agent/2.159.2/vsts-agent-linux-x64-2.159.2.tar.gz",
      "tar zxvf vsts-agent-linux-x64-2.159.2.tar.gz",
      "export VSTS_AGENT_INPUT_URL=https://dev.azure.com/g3rv4",
      "export VSTS_AGENT_INPUT_AUTH=pat",
      "export VSTS_AGENT_INPUT_TOKEN=${var.agent_pat}",
      "export VSTS_AGENT_INPUT_POOL=default",
      "export VSTS_AGENT_INPUT_AGENT=punty",
      "./config.sh --unattended --acceptTeeEula --replace",
      "sudo ./svc.sh install",
      "sudo ./svc.sh start",
      "EOF"
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