resource "yandex_container_registry" "app" {
  name = "${var.env_name}-registry"
}