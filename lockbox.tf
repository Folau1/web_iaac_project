resource "yandex_lockbox_secret" "mysql_password" {
  name        = "${var.env_name}-mysql-password"
  description = "MySQL password for diploma application"

  password_payload_specification {
    password_key        = "db_password"
    length              = 20
    include_punctuation = false
  }
}

resource "yandex_lockbox_secret_version" "mysql_password" {
  secret_id = yandex_lockbox_secret.mysql_password.id
}

data "yandex_lockbox_secret_version_entry" "mysql_password" {
  secret_id  = yandex_lockbox_secret.mysql_password.id
  version_id = yandex_lockbox_secret_version.mysql_password.id
  key        = "db_password"
}