resource "yandex_vpc_security_group" "mysql" {
  name       = "${var.env_name}-mysql-sg"
  network_id = module.vpc.network_id

  ingress {
    description    = "Web application"
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
