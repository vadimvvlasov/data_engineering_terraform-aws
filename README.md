Ниже — полноценный туториал, повторяющий структуру видео из курса (основы Terraform + работа с облачным хранилищем), но полностью переведённый на AWS. Всё можно выполнить с нуля, имея только аккаунт AWS и консоль.

---

## Что мы сделаем
- Создадим IAM-пользователя (аналог GCP Service Account) и получим ключи доступа
- Установим Terraform и настроим AWS CLI
- Напишем конфигурацию Terraform для создания S3-бакета
- Выполним `terraform init`, `plan`, `apply` и `destroy`
- Разберём управление состоянием и переменные

Никаких лишних сервисов — только то, что нужно для первого знакомства с Terraform в AWS.

---

## 1. Подготовка окружения

### 1.1. Terraform
Установите Terraform (версия ≥ 1.5) по [официальной инструкции](https://developer.hashicorp.com/terraform/downloads).  
Проверка:
```bash
terraform version
```

### 1.2. AWS CLI
Установите AWS CLI и настройте профиль. В видео использовался локальный способ, мы поступим аналогично, но без сохранения секретов в открытом виде.

Если у вас уже настроен дефолтный профиль для другого аккаунта и вы не хотите его перезаписать, используйте **named profile**:
```bash
aws configure --profile dtc
```
Это создаст отдельный профиль `dtc` в `~/.aws/credentials` и `~/.aws/config`, не затронув дефолтный аккаунт.

Активировать профиль для текущей сессии терминала:
```bash
export AWS_PROFILE=dtc
```
После этого все команды AWS CLI и Terraform в этой сессии будут использовать профиль `dtc`.

Либо передавать профиль явно в каждой команде:
```bash
aws s3 ls --profile dtc
```

Мы будем передавать ключи через переменные окружения, чтобы полностью контролировать аутентификацию в Terraform.

---

## 2. Создание IAM-пользователя (аналог Service Account)

В оригинале создавался Service Account с правами на Storage Object Admin. У нас будет IAM‑пользователь с политикой, позволяющей управлять S3.

### Через консоль AWS
1. Перейдите в IAM → Users → Create user  
2. Имя: `terraform-user` (или любое), отметьте **Programmatic access** (консольный доступ не нужен) — в новом интерфейсе это опция «Provide user access to the AWS Management Console» **выключена**, а ключи доступа генерируются позже.  
3. Прикрепите политику `AmazonS3FullAccess` (для туториала достаточно; в реальности лучше сузить до одного бакета).  
4. Завершите создание.  
5. В карточке пользователя перейдите на вкладку **Security credentials** → **Create access key** → выберите **Application running outside AWS** → сохраните **Access Key ID** и **Secret Access Key**.

### Экспорт ключей в терминал
В каждой сессии терминала задайте переменные среды (как в видео экспортировались `GOOGLE_APPLICATION_CREDENTIALS`):
```bash
export AWS_ACCESS_KEY_ID="my_access_key"
export AWS_SECRET_ACCESS_KEY="my_secret"
export AWS_DEFAULT_REGION="us-east-1"   # регион по умолчанию
```
Теперь Terraform будет использовать их автоматически.

---

## 3. Структура проекта

Создайте пустую папку для проекта, например `learn-terraform-aws`:
```bash
mkdir data_engineering_terraform-aws
cd data_engineering_terraform-aws
```
Создадим два файла:
- `main.tf` – основная конфигурация
- `variables.tf` – опциональные переменные (в видео переменная для названия бакета)

---

## 4. Конфигурация Terraform

### 4.1. `main.tf`
```hcl
# Провайдер AWS
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# S3 бакет — аналог GCS bucket из видео
resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name     # имя бакета должно быть глобально уникальным
}

# Управление версионированием (в видео Storage Class и lifecycle)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Жизненный цикл: удалять старые версии объектов через 7 дней (как в GCS lifecycle)
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Блокировка публичного доступа (по умолчанию включена, но зафиксируем явно)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### 4.2. `variables.tf`
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
  default     = "my-first-terraform-bucket-20260508"  # замените на своё уникальное имя!
  # Подсказка: можно использовать случайный суффикс, чтобы избежать конфликтов
}
```

> В видео название бакета задаётся переменной с дефолтным значением — мы повторили тот же паттерн. При apply можно переопределить имя, подав `-var "bucket_name=..."`.

---

## 5. Основные команды Terraform

Полное повторение сценария из видео.

### 5.1. `terraform init`
Загружает провайдер AWS и инициализирует рабочую директорию:
```bash
terraform init
```
Будет создан `.terraform.lock.hcl`, фиксирующий версии провайдера.

### 5.2. `terraform plan`
Превью изменений без их применения:
```bash
terraform plan
```
Вы увидите план создания S3-бакета, его версионирования, lifecycle и настроек публичного доступа.  
Аналог «полусухого прогона» в GCP.

### 5.3. `terraform apply`
Запуск создания ресурсов:
```bash
terraform apply
```
Terraform снова покажет план и запросит подтверждение (yes/no). Это ровно как в видео.  
После подтверждения в AWS будет создан бакет. Состояние (`terraform.tfstate`) сохранится локально в папке проекта.

### 5.4. Проверка в консоли AWS
Перейдите в S3 → Buckets, убедитесь, что бакет создан, версионирование включено, lifecycle rule присутствует. Можно загрузить тестовый файл и увидеть его версии.

### 5.5. `terraform destroy`
Удаление всего, что было создано (тщательно используется в туториале):
```bash
terraform destroy
```
После подтверждения бакет и все ассоциированные ресурсы будут удалены из AWS.

---

## 6. Важные замечания (параллели с видео)

- В оригинале состояние хранилось локально, что допустимо для обучения. В реальной работе на AWS настоятельно рекомендуется удалённый backend — S3-бакет + DynamoDB для блокировок (это буквально стандарт «S3 backend»). В видео это не затрагивается, но полезно знать на будущее.
- В GCP использовался `google_storage_bucket_iam_binding`, у нас для простоты нет IAM политик на уровне бакета, но можно добавить политику доступа (например, сделать бакет приватным — он и так приватный по умолчанию).
- Ключи доступа AWS экспортируются в переменные среды — аналог JSON-файла сервисного аккаунта. В production ключи лучше не хранить в открытом виде, а использовать AWS CLI credentials file или Vault.
- Версионирование включено специально, чтобы продемонстрировать lifecycle rule (удаление неактуальных версий), как в видео был настроен lifecycle на удаление объектов через N дней. У нас — удаление старых версий через 7 дней.

---

## 7. Файлы проекта (всё вместе)

```
data_engineering_terraform-aws/
├── main.tf
├── variables.tf
└── .terraform/            (появится после init)
```

Полный код для копирования:

**main.tf**
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**variables.tf**
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
  default     = "my-first-terraform-bucket-20260508"
}
```

---

## Итог

Вы получили прямое пошаговое воспроизведение видео‑туториала на AWS:
- локальная аутентификация через ключи IAM-пользователя
- создание инфраструктуры из terraform-конфигурации
- полный цикл init → plan → apply → destroy
- управление версиями и жизненным циклом объектов S3

Теперь вы можете продолжить экспериментировать: добавить `aws_s3_object` для загрузки файлов из Terraform, внедрить remote state на S3, или перенести IAM-политику на конкретный бакет. Удачи!