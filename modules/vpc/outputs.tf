output "network_id" {
  value = yandex_vpc_network.develop.id
}

output "default_security_group_id" {
  value = yandex_vpc_network.develop.default_security_group_id
}

output "subnets" {
  value = yandex_vpc_subnet.subnet
}

