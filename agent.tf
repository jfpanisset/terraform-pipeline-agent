resource "google_compute_instance" "default" {
  name         = "${var.agent_name}"
  machine_type = "${var.gcp_machine_type}"
  zone         = "${var.gcp_zone}"

  boot_disk {
    initialize_params {
      # image = "ubuntu-1804-bionic-v20191021" // used when creating the image
      image = "pipelines-agent"
    }
  }

  # // used when creating the image
  # metadata = {
  #   user-data = "${file("user_data.yml")}"
  # }

  scheduling {
    preemptible       = true
    automatic_restart = false
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
      network_tier = "STANDARD"
    }
  }

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["http-server"]

  connection {
      user = "agent"
      type = "ssh"
      private_key = "${base64decode(var.ssh_pvt_key_base64)}"
      timeout = "2m"
      host = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sh /wait-for-cloud-init.sh",

      # configure the pipelines agent manager
      "echo '{' > ~/.PipelinesAgentManager",
      "echo '\"TerraformToken\": \"${var.terraform_token}\",' >> ~/.PipelinesAgentManager",
      "echo '\"PipelinesPAT\": \"${var.pipelines_provisioner_pat}\",' >> ~/.PipelinesAgentManager",
      "echo '\"PipelinesOrg\": \"${var.pipelines_org}\",' >> ~/.PipelinesAgentManager",
      "echo '\"DefaultWorkspace\": \"${var.terraform_workspace}\",' >> ~/.PipelinesAgentManager",
      "echo '\"DefaultPoolId\": ${var.pipelines_pool_id}' >> ~/.PipelinesAgentManager",
      "echo '}' >> ~/.PipelinesAgentManager",

      # install it and add the destroy to the cron
      "dotnet tool install --global PipelinesAgentManager.Cli",
      "echo \"* * * * * agent $HOME/.dotnet/tools/PipelinesAgentManager destroy -m 20 >> $HOME/PipelinesAgentManagerDestroy.log 2>&1\" | sudo tee /etc/cron.d/PipelinesAgentManager",
      "echo \"* * * * * agent $HOME/.dotnet/tools/PipelinesAgentManager applyIfNeeded >> $HOME/PipelinesAgentManagerApply.log 2>&1\" | sudo tee -a /etc/cron.d/PipelinesAgentManager",

      # run the actual agent
      "cd agent",
      "export VSTS_AGENT_INPUT_TOKEN=${var.pipelines_agent_pat}",
      "./config.sh --unattended --acceptTeeEula --replace --url https://dev.azure.com/${var.pipelines_org} --auth pat --pool ${var.pipelines_pool_name} --agent ${var.agent_name}",
      "sudo ./svc.sh install",
      "sudo ./svc.sh start",
    ]
  }

  provisioner "remote-exec" {
    when   = "destroy"
    on_failure = "continue"
    inline = [
      "cd ~/agent",
      "sudo ./svc.sh stop",
      "sudo ./svc.sh uninstall",
      "export VSTS_AGENT_INPUT_TOKEN=${var.pipelines_agent_pat}",
      "./config.sh remove --url https://dev.azure.com/${var.pipelines_org} --auth pat --pool ${var.pipelines_pool_name} --agent ${var.agent_name}",
    ]
  }
}

resource "google_compute_firewall" "http-server" {
  name    = "default-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  // Allow traffic from everywhere to instances with an http-server tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "cloudflare_record" "agent" {
  zone_id = "${var.cloudflare_zone_id}"
  name    = "${var.agent_name}"
  value   = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
  type    = "A"
  ttl     = 120
}

output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}
