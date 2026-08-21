#  Рандомный пароль для базы.

resource "yandex_mdb_mysql_user" "app" {
  cluster_id = yandex_mdb_mysql_cluster.mysql.id
  name       = "app"
  password   = data.yandex_lockbox_secret_version_entry.mysql_password.text_value

  permission {
    database_name = yandex_mdb_mysql_database.app.name
    roles         = ["ALL"]
  }
}
# Сама база с user и database

resource "yandex_mdb_mysql_cluster" "mysql" {
  name               = "${var.env_name}-mysql"
  environment        = "PRODUCTION"
  network_id         = module.vpc.network_id
  version            = "8.0"
  security_group_ids = [yandex_vpc_security_group.mysql.id]

  resources {
    resource_preset_id = "s2.micro"
    disk_type_id       = "network-ssd"
    disk_size          = 10
  }

  host {
    zone             = "ru-central1-a"
    subnet_id        = module.vpc.subnets["ru-central1-a"].id
    assign_public_ip = false
  }
}
resource "yandex_mdb_mysql_database" "app" {
  cluster_id = yandex_mdb_mysql_cluster.mysql.id
  name       = "app"
}
