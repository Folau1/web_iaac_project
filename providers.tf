variable "env_name" {
  type        = string
  description = "Имя окружения и VPC"
}

variable "subnets" {
  type = list(object({
    zone = string
    cidr = string
  }))

  description = "Список подсетей"
}

terraform {
  required_version = "~> 1.12.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.222"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
}