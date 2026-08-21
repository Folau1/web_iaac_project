resource "yandex_iam_service_account" "registry_puller" {
  name        = "${var.env_name}-registry-puller"
  description = "Service account for pulling Docker images"
}

resource "yandex_container_registry_iam_binding" "puller" {
  registry_id = yandex_container_registry.app.id
  role        = "container-registry.images.puller"

  members = [
    "serviceAccount:${yandex_iam_service_account.registry_puller.id}"
  ]
}