module "vpc" {
  source = "./modules/vpc"

  env_name = var.env_name
  subnets  = var.subnets
}

resource "yandex_vpc_security_group" "web" {
  name       = "diploma-web-sg"
  network_id = module.vpc.network_id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 8090
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
