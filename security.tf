resource "yandex_vpc_security_group" "mysql" {
  name       = "${var.env_name}-mysql-sg"
  network_id = module.vpc.network_id

  ingress {
    description    = "MySQL from web subnet"
    protocol       = "TCP"
    port           = 3306
    v4_cidr_blocks = module.vpc.subnets["ru-central1-b"].v4_cidr_blocks
  }
}