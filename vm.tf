data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "web" {
  name        = "diploma-web"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  service_account_id        = yandex_iam_service_account.registry_puller.id
  allow_stopping_for_update = true


  depends_on = [
    yandex_container_registry_iam_binding.puller,
    yandex_mdb_mysql_user.app,
    yandex_lockbox_secret_version.mysql_password
  ]
  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id          = module.vpc.subnets["ru-central1-b"].id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.tftpl", {
      ssh_public_key = var.public_key

      docker_compose_b64 = base64encode(
        file("${path.module}/app/docker-compose.yml")
      )

      env_b64 = base64encode(
        templatefile("${path.module}/app/.env.tftpl", {
          registry_id    = yandex_container_registry.app.id
          mysql_host     = yandex_mdb_mysql_cluster.mysql.host[0].fqdn
          mysql_user     = yandex_mdb_mysql_user.app.name
          mysql_password = data.yandex_lockbox_secret_version_entry.mysql_password.text_value
          mysql_database = yandex_mdb_mysql_database.app.name
        })
      )
    })
  }
}
