variable "swarm_managers" {}
variable "dynamic_ip" {}
variable "enable_ipv6" {}
variable "private_key" {}
variable "image" {}
variable "type" {}
variable "security_group" {}
variable "swarm_network" {}
variable "swarm_domain" {}

resource "scaleway_ip" "manager_ip" {
  server = "${scaleway_server.manager.id}"
}

resource "scaleway_server" "manager" {
  count = "${var.swarm_managers}"
  name  = "swarm-manager-${count.index + 1}"
  image = "${var.image}"
  type  = "${var.type}"

  enable_ipv6         = "${var.enable_ipv6}"
  security_group      = "${var.security_group_id}"
  dynamic_ip_required = "${var.dynamic_ip}"

  tags = [
    "swarm",
    "manager",
  ]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = "${file("${path.root}/${var.private_key}")}"
  }

  security_group = "${var.security_group}"

  provisioner "remote-exec" {
    inline = [
      "docker swarm init --advertise-addr ${self.private_ip} --listen-addr ${self.private_ip}",
      "apt-get install ufw",
      "ufw allow 22/tcp",
      "ufw allow 22/tcp",
      "ufw allow 2376/tcp",
      "ufw allow 2377/tcp",
      "ufw allow 7946/tcp",
      "ufw allow 7946/udp",
      "ufw allow 4789/udp",
      "ufw allow 5090/tcp",
      "ufw allow 80/tcp",
      "ufw allow 8080/tcp",
      "ufw allow 9000/tcp",
      "ufw allow to any from any proto esp",
      "echo 'y' | ufw enable",
      "systemctl restart docker",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "curl -L https://github.com/docker/compose/releases/download/1.11.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose",
      "chmod +x /usr/local/bin/docker-compose",
      "docker network create --driver overlay --opt encrypted ${var.swarm_network}",
      "docker volume create --name portainer-data",
      "docker service create --name portainer --publish 9000:9000 --constraint 'node.role == manager' --mount source=portainer-data,target=/data --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock portainer/portainer -H unix:///var/run/docker.sock",
      "docker service create --name gui --publish 5090:8080 --constraint 'node.role == manager' --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock julienbreux/docker-swarm-gui",
      "docker service create --name watchtower --constraint 'node.role == manager' --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock centurylink/watchtower --cleanup",
      "docker service create --name traefik --publish 80:80 --publish 443:443 --publish 8080:8080 --constraint 'node.role==manager' --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock --network ${var.swarm_network} traefik:1.2.0-rc2 --docker --docker.swarmmode --docker.exposedbydefault=false --docker.domain=${var.swarm_domain} --docker.watch --web",
      "docker service create --name whoami0 --label traefik.port=80 --label traefik.docker.network=${var.swarm_network} --label traefik.enable=true --network ${var.swarm_network} emilevauge/whoami",
    ]
  }
}

output "public_ip" {
  value = "${scaleway_server.manager.public_ip}"
}

output "private_ip" {
  value = "${scaleway_server.manager.private_ip}"
}