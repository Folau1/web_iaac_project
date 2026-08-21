#создаем облачную сеть
resource "yandex_vpc_network" "develop" {
  name = var.env_name
}

#создаем подсеть
resource "yandex_vpc_subnet" "subnet" {
  for_each = {
    for subnet in var.subnets : subnet.zone => subnet
  }

  name           = "${var.env_name}-${each.value.zone}"
  zone           = each.value.zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = [each.value.cidr]
}

moved {
  from = yandex_vpc_subnet.develop_a
  to   = yandex_vpc_subnet.subnet["ru-central1-a"]
}