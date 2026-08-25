module "vpc" {
  source = "./modules/vpc"

  env_name = var.env_name
  subnets  = var.subnets
}

locals {
  web_ingress_rules = {
    ssh = {
      description = "SSH"
      port        = 22
    }

    http = {
      description = "HTTP"
      port        = 80
    }

    https = {
      description = "HTTPS"
      port        = 443
    }

    app = {
      description = "Web application"
      port        = 8090
    }
  }
}

resource "yandex_vpc_security_group" "web" {
  name       = "diploma-web-sg"
  network_id = module.vpc.network_id

  dynamic "ingress" {
    for_each = local.web_ingress_rules

    content {
      description    = ingress.value.description
      protocol       = "TCP"
      port           = ingress.value.port
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}