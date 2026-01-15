# global/

Назначение: общие ресурсы организации. Создаются один раз.

## global/backend

Инфраструктура для хранения terraform state. Cчитается секретом уровня infra-root.

Состав:
s3.tf — бакет для state
dynamodb.tf — locking
kms.tf — шифрование state

Terraform state =
– полная карта инфраструктуры
– IAM, IP, DNS, topology
– чувствительные данные

Решает 4 задачи:
Централизованное хранение state
Блокировка параллельных apply
Шифрование
Аудит доступа

Создаётся один раз.
Используется всеми environment.

– state зашифрован
– race condition исключены
– аудит доступа
– blast radius минимален

Вывод
global/backend — корень доверия всей инфраструктуры.

Архитектура backend в AWS

– S3 → хранение state
– DynamoDB → locking
– KMS → шифрование
– IAM → контроль доступа

### global/backend/s3.tf

"aws_s3_bucket" "terraform_state"
Назначение:
– физическое хранилище state
– отдельный бакет только под Terraform

Почему:
– нельзя мешать с app-бакетами
– проще аудит и политики

"aws_s3_bucket_versioning" "this"
Зачем:
– история изменений state
– возможность отката
– защита от случайного удаления

Enterprise-требование.

"aws_s3_bucket_server_side_encryption_configuration" "this"
Зачем:
– state содержит секреты
– шифрование обязательно

Почему KMS, а не AES256:
– контроль ключей
– аудит
– ротация

"aws_s3_bucket_public_access_block" "this"
Зачем:
– защита от ошибок инженеров
– даже при ошибочной policy бакет не станет public

Это guardrail.

### global/backend/dynamodb.tf

"aws_dynamodb_table" "terraform_lock"
Назначение:
– locking Terraform state

Что решает:
– два apply одновременно = запрещено
– защита от race condition

Почему DynamoDB:
– managed
– HA
– cheap

### global/backend/kms.tf

"aws_kms_key" "terraform"
Зачем:
– собственный ключ под Terraform
– изоляция от других сервисов

Почему rotation = true:
– compliance
– long-living state

"aws_kms_alias" "terraform" 
Зачем alias:
– читаемость
– удобство ротации
– не хардкодить key_id

---

## global/iam

Роли и политики для Terraform и аварийного доступа.

Состав:

- `terraform-role.tf` — IAM роль, под которой запускается Terraform (CI/CD или человек).  
- `policies/` — отдельные policy-документы для разных целей:
  - `permission-boundary.tf` — жёсткий потолок прав для всех Terraform-ролей, ограничивает эскалацию.  
  - `terraform-base.tf` — базовый набор разрешений для Terraform (инфраструктура, минимальные IAM-операции).  
- `attach.tf` — связывает роли и политики декларативно, позволяет менять политики без редактирования роли.  
- `break-glass.tf` — аварийная роль с AdministratorAccess для security-team, MFA обязателен, каждый Assume логируется.

Отвечает на вопросы:
– кто имеет право создавать инфраструктуру
– с какими правами
– как это аудируется
– как это отзывается

Best practices:
– Terraform никогда не работает под user credentials
– только через IAM Role + AssumeRole
– с жёстким least privilege

Что решает global/iam
Убирает long-lived access keys
Даёт централизованный контроль прав
Позволяет enforce security через IAM, а не договорённости
Упрощает аудит (CloudTrail)

Архитектура IAM для Terraform (AWS)

– IAM Role: terraform-exec-role
– Trust policy: кто может её assume
– Inline / managed policies: что Terraform может делать
– Разделение:
– platform-infra
– app-infra
– read-only

Далее: Platform-infra.

### global/iam/terraform-role.tf

IAM Role
"aws_iam_role" "terraform"
Пояснение:
– terraform-exec-role — роль, под которой работает Terraform
– AssumeRole — обязательный механизм, без прямых ключей
– Principal — кто имеет право запускать Terraform
– CI/CD аккаунт
– bastion
– security account

В enterprise это не root, а отдельный account.

Почему AssumeRole — критично

– ключи не утекут
– сессии короткоживущие
– можно мгновенно отозвать доступ
– CloudTrail пишет, кто и когда

### global/iam/policies/terraform-base.tf

Базовая policy Terraform
"aws_iam_policy" "terraform_base"
Пояснение по блокам:

– ec2 / elb / asg
Управление compute и network-ресурсами

– iam:*Role
Terraform должен уметь создавать роли
Без этого невозможно EKS / IRSA / node roles

– iam:PassRole
Самый опасный permission
Нужен, чтобы EC2/EKS могли использовать роли

– kms / s3 / dynamodb
backend, encryption, state, locking

– logs / cloudwatch
observability infra-уровня

Почему Resource = "*":
– на старте обучения
– потом режется SCP и OPA

### global/iam/policies/permission-boundary.tf

`aws_iam_policy "terraform_boundary"`
Жёсткий потолок прав для всех Terraform-ролей. Boundary **не даёт прав**, а **ограничивает эскалацию**.

**Назначение:** задаёт максимальный безопасный набор разрешений для Terraform.  

**Разрешает:**
- Управление инфраструктурой: EC2, VPC, S3, ELB, AutoScaling, EKS, CloudWatch, Logs  
- Минимальные IAM-операции для инфраструктуры: создание/удаление ролей, attach/detach policy, pass role  

**Запрещает:**
- Создание или удаление пользователей и политик (IAM escalation)  
- Изменение организаций и аккаунтов (Organizations, Account)  

**Ключевой момент:** policy сама по себе **не выдаёт права**, она **ограничивает максимум** того, что может делать роль.  

**Применение:** обязательно указывать в каждой Terraform-роли через  
`permission_boundary = aws_iam_policy.terraform_boundary.arn`.

### global/iam/attach.tf

`aws_iam_role_policy_attachment "terraform_attach"`  
- Связывает роль и policy  
- Декларативно и безопасно  
- Позволяет менять политики без изменения роли  

---

### global/iam/break-glass.tf

`aws_iam_role "break_glass"`  
- Assume только root / security-team  
- MFA обязательно  
- Terraform **не имеет trust**  
- Каждое использование полностью логируется  

`aws_iam_role_policy_attachment "break_glass_admin"`  
- Роль не используется в обычной работе  
- Любое Assume → инцидент и аудит  

---

## global/org-policies

Организационные политики безопасности и лимиты. Последний защитный слой платформы: даже при ошибках в IAM или Terraform опасные действия будут заблокированы на уровне организации.

IAM управляет доступом. SCP управляют безопасностью. SCP не выдают прав — они жёстко ограничивают допустимые действия.

Реализовано через AWS Organizations и Service Control Policies. Политики применяются к OU и аккаунтам.

Состав:

- `guardrails.tf` — базовые SCP-запреты  
  - public exposure  
  - отсутствие шифрования  
  - запрещённые регионы

- `scp.tf` — системные SCP  
  - защита audit/logging  
  - запрет критичных отключений безопасности

- `quotas.tf` — сервисные и ресурсные лимиты

### global/org-policies/guardrails.tf

Запрет public S3
"aws_organizations_policy" "deny_public_s3"
Пояснение:
– Даже если IAM разрешает
– Даже если Terraform настроен неправильно
– Public S3 не появится

Это защита от человеческой ошибки.

Запрет EC2 без шифрования дисков
"aws_organizations_policy" "deny_unencrypted_ebs"
Пояснение:
– Любой диск без encryption = запрещён
– Даже для Terraform role

Compliance-уровень контроль.

Запрет опасных регионов
"aws_organizations_policy" "deny_unsupported_regions"
Пояснение:
– Infrastructure только в разрешённых регионах
– Упрощает compliance
– Убирает shadow-infra

### global/org-policies/quotas.tf

Ограничение количества EC2
"aws_organizations_policy" "limit_ec2"
Пояснение:
– Защита от runaway scaling
– Контроль затрат
– Особенно важно при autoscaling

Привязка SCP к OU / account
"aws_organizations_policy_attachment" "attach_guardrails"
Пояснение:
– Политика применяется ко всем account в OU
– Централизованное управление
– Terraform сам себя ограничивает

### global/org-policies/scp.tf

"aws_organizations_policy" "security_guardrails"
Пояснение
Effect = Deny — абсолютный запрет
Resource = "*" — на всё
Condition — защита от ошибок Terraform
IAM не может обойти SCP

Что делает:
запрещает удаление audit-логов
запрещает отключение шифрования
запрещает создание публичных ресурсов

---

# modules/

Назначение: переиспользуемая бизнес-логика. Основа всего.

## modules/shared

Вспомогательные абстракции.

Состав:
labels/ — стандартные labels
naming/ — единые имена ресурсов
tags/ — cost/allocation
locals.tf — общие locals

modules/shared — это инфраструктурный язык компании.

Он решает:
– единые имена ресурсов
– единые теги
– единые labels
– единые locals

В top-companies:
– shared не создаёт ресурсов
– shared навязывает стандарты

Без него:
– хаос
– невозможный аудит
– плохой DevSecOps и incident response

Cмысл modules/shared:
Все ресурсы одинаково именованы
Все ресурсы тегированы
Любой ресурс можно отследить
Compliance автоматизируется

### modules/shared/naming

Назначение
– стандартизировать имена ресурсов
– избежать коллизий
– упростить аудит и поиск

#### modules/shared/naming/locals.tf

Пояснение:
– org — организация
– project — продукт
– env — окружение

Итог:
org-project-env

Пример:
acme-health-prod

#### modules/shared/naming/variables.tf

Почему явно задано:
– никаких magic values
– читаемость
– reuse

#### modules/shared/naming/outputs.tf

Использование:
– все ресурсы именуются через этот prefix

### modules/shared/tags

Назначение
– cost allocation
– ownership
– audit
– security

Теги — обязательны в enterprise.

#### modules/shared/tags/locals.tf

Пояснение:
– ManagedBy — автоматический аудит
– Owner — ответственность
– CostCenter — финансы

#### modules/shared/tags/variables.tf

#### modules/shared/tags/outputs.tf

Используется в каждом ресурсе.

### modules/shared/labels

Назначение
– Kubernetes
– Cloud-native metadata
– observability

Labels ≠ tags.
Они живут дольше и глубже.

Состав:
- `modules/shared/labels/locals.tf`
- `modules/shared/labels/variables.tf`
- `modules/shared/labels/outputs.tf`

### modules/shared/locals.tf

Назначение
– глобальные вычисляемые значения
– reuse между модулями

#### modules/shared/locals.tf

Пояснение:
– логика окружений централизована
– no copy-paste
– предсказуемое поведение

---

## modules/network

Сетевой необратимый фундамент.

Состав:

- `vpc/` — VPC / VNet  
- `subnets/` — публичные и приватные подсети  
- `nat/` — outbound-доступ в интернет  
- `routing/` — таблицы маршрутизации  
- `main.tf` — реализация сети (VPC, подсети, маршруты, NAT)  
- `variables.tf` — параметры сети (CIDR, AZ, флаги)  
- `outputs.tf` — экспорт сетевых идентификаторов для других модулей

Он решает:
– изоляцию окружений
– control / data plane separation
– ingress / egress контроль
– blast radius
– zero-trust основу

Best practices:
– меняется редко
– проектируется заранее
– отделена от compute и security логически

Границы ответственности:
– маршруты
– подсети
– gateways

Ответственности:
– VPC
– Subnets (public / private)
– Internet Gateway
– NAT Gateway
– Route Tables

Внутреннее дробление (vpc/, subnets/, nat/, routing/) показано концептуально. 
В enterprise-платформах эти части выносятся в отдельные подмодули. 
В текущем проекте используется единый модуль `network` с одной ответственностью с полной реализацией в `main.tf`.

DevSecOps-смысл modules/network

Что обеспечено:
– network isolation
– минимальный attack surface
– predictable routing
– соответствие zero-trust модели

Без network-модуля:
– security невозможна
– kubernetes нестабилен

Итог

modules/network — это:
– первый реально создающий ресурсы модуль
– фундамент всей платформы
– точка, где ошибки самые дорогие

### modules/network/variables.tf

Назначение
– явно задать сетевую модель

Реализация:
– сеть параметризуема
– легко менять размер
– удобно для dev/stage/prod

### modules/network/main.tf

VPC
"aws_vpc" "this"
Пояснение:
– DNS обязателен для Kubernetes
– один VPC = одно окружение
– теги обязательны

Internet Gateway
"aws_internet_gateway" "this"
Зачем:
– доступ из public subnet в интернет
– ingress точка

Public Subnets
"aws_subnet" "public"
Пояснение:
– ALB, NAT, bastion
– public IP разрешён
– минимум ресурсов

Private Subnets
"aws_subnet" "private"
Пояснение:
– worker nodes
– базы
– no public IP
– основная зона безопасности

NAT Gateway
"aws_eip" "nat"
Пояснение:
– private → internet
– обновления
– outbound only
– single NAT для портфолио (в prod часто per-AZ)

Route Tables
Public:
"aws_route_table" "public"
Private:
"aws_route_table" "private"
Пояснение:
– чёткий ingress / egress
– private не знает про IGW
– public не имеет NAT

### modules/network/outputs.tf

Зачем:
– используется compute
– используется security
– используется kubernetes

---

## modules/security

Сетевая и perimeter-безопасность.

Состав:

- `security-groups/` — правила сетевого доступа (SG / firewall rules)
- `nsg/` — cloud-native network security (NSG / equivalents)
- `firewall/` — L7/L4 защита: WAF, FW
- `main.tf` — реализация сетевой и perimeter-безопасности
- `variables.tf` — параметры правил и режимов безопасности
- `outputs.tf` — экспорт security-идентификаторов для других модулей

Решает задачи:
– кто с кем может общаться
– откуда возможен ingress
– куда разрешён egress
– минимизацию attack surface

Best practicies:
– сеть ≠ безопасность
– security живёт отдельно
– правила читаются как политика, а не как «случайный код»
– Security groups (SG) делим по ролям, а не по ресурсам.

Границы ответственности:
– firewall-логика
– security groups
– network segmentation

Минимально правильная ролевая модель SG для k8s:
sg-control-plane
sg-workers
sg-ingress (ALB / LB)
sg-egress (явный outbound)

Подкаталоги security-groups/, nsg/, firewall/ отражают enterprise-декомпозицию. 
В enterprise-платформах эти части выносятся в отдельные подмодули. 
В текущем проекте используется единый модуль `security` с одной ответственностью с полной реализацией в `main.tf`.

DevSecOps-смысл modules/security

Что обеспечено:

– один public ingress
– zero-trust внутри VPC
– минимальный attack surface
– читаемая security-модель
– правила как код

Security review читается без схем и созвонов.

Типовые ошибки, которых уже нет

– 0.0.0.0/0 на ноды
– смешивание SG и network
– implicit trust
– copy-paste правил

Итог

modules/security — это:
– формализация доверия
– основа zero-trust
– обязательный слой перед compute и k8s

Без него Kubernetes = открытая цель.

### modules/security/variables.tf

– security жёстко привязана к VPC
– CIDR нужен для east-west правил

### modules/security/main.tf

Ingress / LB Security Group
"aws_security_group" "ingress"
Пояснение:
– единственная точка public ingress
– только 80/443
– дальше трафик идёт внутрь VPC

Control Plane SG
"aws_security_group" "control_plane"
Пояснение:
– API доступен только воркерам
– нет public доступа
– east-west разрешён внутри VPC

Worker Nodes SG
"aws_security_group" "workers"
Пояснение:
– workers не принимают public traffic
– общаются только внутри кластера
– egress открыт, ingress ограничен

### modules/security/outputs.tf

– compute и kubernetes используют эти SG
– жёсткая связка через outputs, не через data lookup

---

## modules/compute

Виртуальные машины и scaling. Отвечает только за вычислительные ресурсы. Предсказуемый слой.

Состав:

- `master-node/` — control-plane ноды  
- `worker-node/` — worker-ноды  
- `autoscaling/` — логика масштабирования  
- `launch-templates/` — шаблоны виртуальных машин  
- `main.tf` — реализация compute-ресурсов (VM, ASG, templates)  
- `variables.tf` — параметры нод и scaling  
- `outputs.tf` — экспорт идентификаторов compute-ресурсов  

Решает задачи:
– сколько нод
– какого типа
– как они масштабируются
– как они пересоздаются

Не знает:
– что это Kubernetes
– какие порты
– какие IAM-политики

Границы ответственности:
– какие ноды существуют

Что входит в modules/compute
– Launch Template
– Auto Scaling Group (workers)
– Отдельные master nodes
– IAM Instance Profile (минимальный)

Подкаталоги master-node/, worker-node/, autoscaling/, launch-templates/ отражают enterprise-декомпозицию.  
В enterprise-платформах эти части выносятся в отдельные подмодули.
В текущем проекте используется единый модуль `compute` с одной ответственностью и полной реализацией в `main.tf`.  

DevSecOps-смысл modules/compute

Что обеспечено:

– immutable infra
– predictable scaling
– no snowflake nodes
– blast radius control
– чёткое разделение master / worker

Compute можно:
– пересоздавать
– масштабировать
– дренировать

Без страха сломать платформу.

Типовые ошибки, которых тут нет:
– ручное создание VM
– разные AMI на нодах
– autoscaling masters
– смешивание compute и k8s

Итог

modules/compute — это:
– управляемая мощность
– без бизнес-логики
– без Kubernetes-знаний

---

### Итоговая картина

global/backend
– где хранится state

global/iam
– кто имеет право его менять
Без global/iam:
– Terraform = опасный скрипт
С global/iam:
– Terraform = управляемая платформа

global/backend — где state
global/iam — кто может менять infra
global/org-policies — что никогда нельзя делать

Границы ответственности

modules/network
– куда ноды подключаются

modules/security
– кто с кем говорит

modules/compute
– какие ноды существуют

modules/kubernetes
– зачем они существуют