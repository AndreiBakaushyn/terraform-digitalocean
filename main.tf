terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.49.2"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

variable "do_token" {}

resource "digitalocean_droplet" "web" {
  name   = "web-droplet"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  image  = "ubuntu-22-04-x64"
}

output "droplet_ip" {
  value = digitalocean_droplet.web.ipv4_address
}
