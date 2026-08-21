output "registry_id" {
  value = yandex_container_registry.app.id
}

output "mysql_host" {
  value = yandex_mdb_mysql_cluster.mysql.host[0].fqdn
}

output "mysql_database" {
  value = yandex_mdb_mysql_database.app.name
}

output "mysql_user" {
  value = yandex_mdb_mysql_user.app.name
}

output "web_public_ip" {
  value = yandex_compute_instance.web.network_interface[0].nat_ip_address
}

