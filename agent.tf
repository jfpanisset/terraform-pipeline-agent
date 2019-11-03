resource "google_compute_instance" "default" {
  name         = "agent"
  machine_type = "n1-standard-2"
  zone         = "us-west2-a"

  boot_disk {
    initialize_params {
      # image = "ubuntu-1804-bionic-v20191021" // used when creating the image
      image = "agent"
    }
  }

  // used when creating the image
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
      "cd ~/agent",
      "sudo ./svc.sh stop",
      "sudo ./svc.sh uninstall",
      "export VSTS_AGENT_INPUT_URL=https://dev.azure.com/g3rv4",
      "export VSTS_AGENT_INPUT_AUTH=pat",
      "export VSTS_AGENT_INPUT_TOKEN=${var.agent_pat}",
      "export VSTS_AGENT_INPUT_POOL=default",
      "export VSTS_AGENT_INPUT_AGENT=punty",
      "./config.sh remove",
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
  name    = "punty"
  value   = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
  type    = "A"
  ttl     = 120
}

output "ip" {
  value = "${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}"
}
