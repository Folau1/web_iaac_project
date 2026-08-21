# Итоговый проект модуля: "Облачная инфрастуктура. Terraform"

## Описание проекта

В рамках дипломного проекта была подготовлена инфраструктура в **Yandex Cloud** с помощью **Terraform**.

Цель: автоматически развернуть веб-приложение в облаке, используя предыдущие домашние задания:

- Terraform;
- Yandex Cloud;
- VPC и Security Groups;
- Compute Cloud;
- Managed Service for MySQL;
- Container Registry;
- Docker и Docker Compose;
- cloud-init;
- Yandex LockBox;
- удалённое хранение Terraform State в Object Storage;
- блокировку Terraform State.

Данное приложение запускается в Docker контейнере и подключается к mysql базе также в облаке. файл README.md написан блоками, с разъеснениями.

---

## Архитектура

```
                         Internet
                            |
                            | TCP 8090
                            v
                  +-------------------+
                  |    Web VM         |
                  |   Ubuntu 22.04    |
                  |                   |
                  | Docker + Compose  |
                  | FastAPI :5000     |
                  +---------+---------+
                            |
                            | TCP 3306
                            v
                  +-------------------+
                  | Managed MySQL 8.0 |
                  |    Private IP     |
                  +-------------------+

        +-------------------+       +-------------------+
        | Container Registry|       | Yandex LockBox    |
        | diploma-app image |       | DB password       |
        +---------+---------+       +---------+---------+
                  |                           |
                  +------------+--------------+
                               |
                               v
                            Terraform
                               |
                               v
                  +--------------------------+
                  | Yandex Object Storage    |
                  | diploma/terraform.tfstate|
                  | + state locking          |
                  +--------------------------+
```

---

## Что было сделано:

### 1. Сеть

Был взять собственный модуль, который делали в 04 задании. В нём уже имеется:

- VPC-сеть;
- подсети в необходимых зонах доступности;
- выходные значения "network_id" и "subnets".

Подсеть передается в модуль через переменные, как мы делали в домашней работе.  Подсети передаются в модуль через переменные. Поэтому ни к одной зоде или cidr не привязана.

---

### 2. Security Groups

Для Web VM настроена группа безопасности с разрешением входящего трафика:

- `22/tcp` — SSH;
- `80/tcp` — HTTP;
- `443/tcp` — HTTPS;
- `8090/tcp` — веб-приложение.

Исходящий трафик для VM разрешён.

Во время настройки приложение на виртуальной машине запускалось, но запросы к нему либо сбрасывались, либо зависали. При этом сам Docker контейнер и FastAPI были запущены корректно.

Проверка показала, что проблема была не в приложении, а в сетевой части: виртуальная машина не могла подключиться к Managed MySQL по порту 3306. Изначально доступ к MySQL был настроен через Security Group веб-сервера, но соединение не проходило.

Проблема была решена изменением правила Security Group MySQL: доступ к порту 3306 был разрешён из приватной подсети приложения.

Для mysql используется отдельная группа безопасности и доступ к ней идёт через "3306/tcp" из приватной сети. 
Таким образом, база не публикуется в интернет.

---

### 3. Виртуальная машина

Terraform создаёт ВМ "diploma-web".

Основные параметры:

- Ubuntu 22.04 LTS;
- публичный NAT IP;
- подключение к VPC;
- Security Group веб-приложения;
- Service Account для скачивания Docker-образов из Container Registry.

Публичный IP не захардкожен и получается через Terraform output:

```
terraform output -raw web_public_ip
```

---

### 4. cloud-init

Первоначальная настройка VM выполняется автоматически через "cloud-init".

Во время первого запуска:

1. обновляются пакеты;
2. устанавливаются Docker и Docker Compose;
3. создаётся пользователь "ubuntu";
4. добавляется SSH-ключ;
5. создаются файлы "/opt/diploma/docker-compose.yml" и "/opt/diploma/.env";
6. VM авторизуется в Yandex Container Registry через IAM-токен Service Account;
7. скачивается Docker-образ приложения;
8. запускается приложение через Docker Compose.

Ручная установка приложения на VM не требуется.

---

## Docker

### Dockerfile

По проекту, готовый код нужно взять из (Задания 5 «Виртуализация и контейнеризация»)

Для приложения используется **multistage Dockerfile**.

На первом этапе устанавливаются Python-зависимости:

```
FROM python:3.12-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
```

На втором этапе создаётся итоговый образ:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY --from=builder /install /usr/local
COPY main.py .

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
```

Это позволяет не переносить в итоговый образ лишние файлы этапа сборки.
Были тоже небольшие проблемы со сборкой, пришлось немного менять сеть.

---

### Docker Compose

Приложение запускается через Docker Compose:

```
services:
  web:
    image: cr.yandex/${REGISTRY_ID}/diploma-app:latest
    restart: unless-stopped

    env_file:
      - .env

    ports:
      - "8090:5000"
```

Порт:

```
VM:8090 -> container:5000
```

---

## Container Registry

Terraform создаёт Yandex Container Registry.

Docker образ приложения собирается локально через Docker Desktop и отправляется в Registry:

```
docker build -t cr.yandex/<REGISTRY_ID>/diploma-app:latest .
docker push cr.yandex/<REGISTRY_ID>/diploma-app:latest
```

Для VM создан отдельный Service Account с ролью:

```
container-registry.images.puller
```

Благодаря этому VM может самостоятельно скачать образ во время выполнения "cloud-init".

---

## Managed MySQL

База данных создаётся через **Yandex Managed Service for MySQL**.

Используется:

- MySQL 8.0;
- отдельная база "app";
- отдельный пользователь "app";
- приватное подключение через VPC;
- публичный IP для MySQL отключён.

Изначально для тестов делал random_password как мы делали в предыдущей домашней работе, после было поменяно и добавлен LockBox(Про это дальше).

Приложение получает параметры подключения через ".env":

```
DB_HOST
DB_USER
DB_PASSWORD
DB_NAME
```

Файл ".env" создаётся на VM автоматически из Terraform-шаблона ".env.tftpl".

---

## Yandex LockBox

Пароль пользователя MySQL не хранится в коде Terraform и не записывается вручную в "terraform.tfvars".

Terraform создаёт секрет:

```
diploma-mysql-password
```

В LockBox создаётся отдельная версия секрета с ключом:

```
db_password
```

После этого Terraform получает значение через:

```
data "yandex_lockbox_secret_version_entry" "mysql_password"
```

Полученный пароль используется:

- для пользователя Managed MySQL;
- для формирования ".env" веб-приложения.

Таким образом, источник пароля у нас Yandex LockBox.

---

## Remote Terraform State

Terraform State хранится удалённо в **Yandex Object Storage**.

Backend:

```
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }

    bucket = "folau1-tfstate-bga82v"
    region = "ru-central1"
    key    = "diploma/terraform.tfstate"

    use_lockfile = true

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
```

State был мигрирован из локального backend:

```
terraform init -migrate-state
```

После миграции объект появился в бакете:

```
diploma/terraform.tfstate
```

Поэтому, даже если мы удалил локально state файлы, мы их можем спокойно взять из облака.

---

## State Locking

Для защиты state от одновременного изменения мы используем код из лекции:

```
use_lockfile = true
```
Данный процесс я проверил, открыв второе окно. 
Получил естественную ошибку (защиту)


```
Error acquiring the state lock
StatusCode: 412
PreconditionFailed
```

Делаем короткий вывод: благодаря state lock изменения не смогут примениться если одновременно будут менять файлы.

---

## Авторизация

Для работы Terraform Provider используются переменные окружения:

```powershell
$Env:YC_TOKEN = $(yc iam create-token)
$Env:YC_CLOUD_ID = $(yc config get cloud-id)
$Env:YC_FOLDER_ID = $(yc config get folder-id)
```

Для доступа S3 backend используются:

```powershell
$Env:AWS_ACCESS_KEY_ID="..."
$Env:AWS_SECRET_ACCESS_KEY="..."
```

Секретные значения в репозиторий не добавляются.

---

## Запуск Terraform

После клонирования репозитория и настройки авторизации:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

После успешного применения Terraform выводит:

```
mysql_database
mysql_host
mysql_user
registry_id
web_public_ip
```

Пароль MySQL через outputs не выводится.

---

## Проверка приложения

Получил публичный IP VM:

```
$ip = terraform output -raw web_public_ip
```

Проверил доступность порта:

```
Test-NetConnection $ip -Port 8090
```

Проверил приложение:

```
curl.exe "http://${ip}:8090/"
```

Проверил записи в MySQL:

```
curl.exe "http://${ip}:8090/requests"
```

Пример результата:

```
{
  "total_records": 6,
  "records": [
    {
      "id": 6,
      "request_date": "2026-08-21 10:46:12",
      "request_ip": null
    }
  ]
}
```

После пересоздания VM старые записи остаются в базе.
Это подтверждается, что данные хранятся в отдельном managed и не завится от жизненного цикла VM или Docker контейнера.

---

## Структура проекта

```
diploma/
├── app/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── main.py
│   ├── requirements.txt
│   └── .env.tftpl
│
├── modules/
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── README.md
│
├── backend.tf
├── cloud-init.yml
├── iam.tf
├── lockbox.tf
├── main.tf
├── mysql.tf
├── outputs.tf
├── providers.tf
├── registry.tf
├── security.tf
├── variables.tf
├── vm.tf
├── terraform.tfvars
└── README.md
```

---

## Всё про безопасность

В проекте:

- пароль MySQL не хранится в Git;
- пароль создаётся через LockBox;
- Managed MySQL не имеет публичного IP;
- доступ к MySQL ограничен Security Group;
- для Container Registry используется отдельный Service Account;
- Terraform State хранится удалённо;
- включена блокировка State;
- ".terraform", локальные state-файлы, ".env" и другие временные файлы не должны попадать в Git.

Пример .gitignore:

```
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
.env
serial*.log
crash.log
```

---

## Результат

В результате Terraform автоматически разворачивает инфраструктуру веб-приложения:

1. создаёт VPC и подсети;
2. создаёт Security Groups;
3. создаёт Managed MySQL;
4. создаёт базу и пользователя;
5. создаёт Container Registry;
6. создаёт Service Account;
7. создаёт секрет пароля в LockBox;
8. создаёт Web VM;
9. через cloud-init устанавливает Docker и Docker Compose;
10. скачивает образ приложения из Container Registry;
11. формирует ".env";
12. запускает FastAPI;
13. приложение записывает и читает данные из Managed MySQL;
14. Terraform State хранится в Object Storage и защищён блокировкой.
---

## Возникшие проблемы по ходу задания.

### Проблема с Yandex LockBox.
Terraform не находил db_password в текущей версии секрета. Решил созданием отдельного yandex_lockbox_secret_version и явным указанием version_id.
### Проблема с Docker Hub.
При запуске VM загрузка дополнительного образа Nginx периодически падала по timeout. Убрал лишний Nginx и опубликовал FastAPI напрямую через Docker Compose 8090:5000.
### Проблема после перезагрузки моего ПК.
Каждый раз, когда я завершал работу над проектом, либо перезагружал ПК, авторизация в Yandex Cloud пропадала. Каждый раз по новой подключаться, немного не нравится.

---

## Итог

Все основные цели проекта были выполнены:
Инфрастуктура, приложение разворачивается средствами IaaC, приложение доступно через публичный белый IP адрес, база вынесена в managed MySQL, Докер образ хранится в Container Registry, секреты вынесены в LockBox, Terraform state хранятся удалённо на облаке.