architecture.md
Структура репозитория (modules/, policies/, scripts/, helm/values/ и т.д.)
Назначение каждого блока/каталога
Взаимосвязь между слоями: cloud / infra / AI / CI/CD / governance
High-level диаграмма infra + AI платформы

Содержит обзор всех папок и компонентов
Ссылки на:
security-model.md (для понимания, какие границы и политики применяются)
workflows.md (для понимания, как инфра меняется и продвигается)
data-flows.md (для понимания, куда идут данные)

_

decision-driven (почему так)
AI Cloud Architecture (GPU, data zones, trust boundaries)
_

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

### modules/security/variables.tf

Пояснение:
– compute полностью параметризован
– environment решает размер
– модуль не хардкодит ничего

### modules/security/main.tf

IAM Role для EC2 (минимальный)
"aws_iam_role" "ec2"
Зачем:
– EC2 не должны работать без роли
– потом сюда добавится IRSA / EBS / SSM

Launch Template (общий для workers)
"aws_launch_template" "worker"
Пояснение:
– immutable VM
– любое изменение = rollout
– основа autoscaling

Auto Scaling Group (workers)
"aws_autoscaling_group" "workers"
Пояснение:
– workers всегда через ASG
– масштабирование безопасно
– подходит для 3 → 50 → 500

Master Nodes (без ASG)
"aws_instance" "master"
Пояснение:
– master ноды контролируем вручную
– scaling осознанный
– стабильность control plane

В enterprise:
– masters почти никогда не autoscale

### modules/security/outputs.tf

– kubernetes/bootstrap
– observability
– controlled lifecycle

---

## modules/kubernetes

Kubernetes-уровень.

Состав:

- `control-plane/` — инициализация и управление control-plane  
- `node-groups/` — группы worker-нод  
- `cni/` — сетевая подсистема кластера  
- `bootstrap/` — первичная инициализация (cloud-init / kubeadm)  
- `templates/master_bootstrap.sh` — bootstrap control-plane нод  
- `templates/worker_join.sh` — подключение worker-нод к кластеру  
- `main.tf` — реализация Kubernetes-кластера и bootstrap-логики  
- `variables.tf` — параметры кластера и bootstrap  
- `outputs.tf` — экспорт kube-идентификаторов и endpoint’ов  

Решает задачи:
– Bootstrap k3s
– что считается кластером
– где граница ответственности
– как формируется control-plane
– как ноды становятся кластером
– какие базовые компоненты обязательны

Не решает:
– конфигурирация внутри (через Ansible)
– деплой приложений
– Helm-чарты сервисов
– бизнес-настройки

Подкаталоги control-plane/, node-groups/, cni/, bootstrap/ отражают enterprise-декомпозицию.  
В enterprise-платформах эти части выносятся в отдельные подмодули.
В текущем проекте используется единый модуль `kubernetes` с одной ответственностью и полной реализацией в `main.tf`.  

DevSecOps-смысл modules/kubernetes

Что обеспечено:

– кластер как infra-object
– воспроизводимый bootstrap
– чёткая граница Terraform / Ansible
– zero-click join нод

Что не делается здесь (как пример):
– ingress
– cert-manager
– monitoring
– apps

Соблюдены best practices:
– каждый слой изолирован
– можно снести и пересобрать сразу ВМ + Kubernetes

Итог

modules/kubernetes — это:
– формализация кластера
– контроль жизненного цикла
– даёт воспроизводимость
– основа для GitOps

Без него DevOps всегда «ручной».

### modules/templates/master_bootstrap.sh

Пояснение:
– отключаем всё лишнее
– платформа минимальна
– дальше только GitOps

### modules/templates/worker_join.sh

Пояснение:
– worker тупой
– он просто присоединяется
– никаких условий

### modules/variables.tf

Пояснение:
– модуль не знает, откуда VM
– IP приходят из modules/compute
– версия кластера фиксируется

### modules/main.tf

Генерация cluster token
"random_password" "k3s_token"
Зачем:
– единый trust для нод
– immutable bootstrap

Bootstrap master
"null_resource" "master_bootstrap"
Пояснение:
– Terraform управляет lifecycle
– bootstrap идемпотентен
– это не «ssh руками»

Join workers
"null_resource" "worker_join" 
Пояснение:
– порядок строго зафиксирован
– workers не живут без control-plane
– масштабирование предсказуемо

### modules/outputs.tf

Зачем:
– передача в Ansible / GitOps
– auditability
– автоматизация

---

## modules/access

Слой идентификации и управления доступом.

Состав:

- `iam/` — управление Cloud IAM (пользователи, роли, политики)  
- `oidc/` — федерация, GitHub OAuth, SSO интеграции  
- `rbac/` — Kubernetes RBAC (роли, binding’и)  
- `main.tf` — реализация ресурсов доступа и связей между ними  
- `variables.tf` — входные параметры доступа (пользователи, роли, права)  
- `outputs.tf` — экспорт идентификаторов ролей, binding’ов и OIDC-конфигураций

Он отвечает:
– кто имеет право
– откуда приходит идентификация
– как доступ маппится в Kubernetes

Это не IAM-файлы, а access architecture.

Архитектурная роль

Разделение ответственности (по best practice):

Cloud access ≠ Kubernetes access ≠ Human access

Поэтому три подпапки:
– iam
– oidc
– rbac

Что делает L2-модуль access;
– собирает identity-слой целиком
– связывает cloud ↔ k8s
– экспортирует контракты для CI и GitOps

DevSecOps-смысл modules/access

Этот модуль:
– убирает static secrets
– вводит federated trust
– разделяет ответственность
– готовит GitOps

Без него:
Terraform = root
Kubernetes = хаос

Итог

modules/access — это:
– identity как система
– не набор ролей
– enterprise-обязательный слой

### modules/access/main.tf

Пояснение:
– жёсткое разделение зон ответственности
– каждый слой можно менять независимо
– никакой мешанины ролей

### modules/access/variables.tf

Пояснение:
– access всегда environment-aware
– нет глобальных ролей «на всё»

### modules/access/outputs.tf

Пояснение:
– используется CI
– используется GitOps
– единая точка интеграции

### modules/access/iam/

Cloud-level identity.

Отвечает:
– кто может менять инфраструктуру
– откуда приходят креды
– как ограничен blast radius

Наполнение: 
– terraform execution role
– ci role (OIDC)
– break-glass role

Почему iam отдельно:
– cloud identity живёт дольше кластера
– она критична
– её нельзя смешивать с k8s

#### modules/access/iam/main.tf

Пояснение:
– отдельная роль под Terraform
– не используется людьми
– легко аудитится

### modules/access/oidc/

Federated identity.

Решает:
– CI без секретов
– GitOps без ключей
– traceable access

Наполнение:
– OIDC provider (напрмиер GitHub, Argo CD)
– trust policy
– ограничение audience

Почему oidc — отдельный слой

OIDC:
– используется и CI
– и GitOps
– и людьми

Это identity backbone, а не частность.

#### modules/access/oidc/

Пояснение:
– стандарт GitHub OIDC
– без long-lived secrets
– enterprise best practice

### modules/access/rbac/

Kubernetes-level access.

RBAC решает:
– кто admin
– кто readonly
– кто cicd

Cloud IAM не управляет pod’ами.

Наполнение:
– ClusterRole
– RoleBinding
– mapping OIDC → RBAC

Почему RBAC не в GitOps (пока)

Потому что:
– сначала нужен identity
– потом access model
– потом GitOps

Иначе получится lockout.

### modules/access/rbac/

Пояснение:
– минимальные права
– принцип least privilege
– platform-safe

---

## modules/observability

Инфраструктурный слой наблюдаемости.

Состав:

- `logging/` — сбор и хранение логов  
- `monitoring/` — метрики и alerting  
- `tracing/` — распределённые трейсы и трассировка запросов  
- `main.tf` — реализация ресурсов наблюдаемости и интеграций  
- `variables.tf` — параметры конфигурации логирования, метрик и трейсов  
- `outputs.tf` — экспорт endpoint’ов, dashboard’ов и ключевых идентификаторов

Он отвечает:
– где хранятся логи
– где живут метрики
– куда пишутся трейсы

Он не отвечает:
– за дашборды приложений
– за алерты конкретных сервисов

Это платформа, не продукт.

Архитектурная роль

Observability начинается до Kubernetes workloads.

Best practices:
– сначала infra-backends
– потом агенты
– потом Grafana
– потом SLO

Что делает L2-модуль observability

– собирает backends
– задаёт стандарты
– экспортирует endpoints
– не зависит от конкретных приложений

Почему observability — infra, а не Helm

Потому что:
– backend живёт дольше кластера
– данные критичнее подов
– storage = зона риска

Агенты и Helm — следующий слой.

DevSecOps-смысл modules/observability

Этот модуль:
– даёт контроль
– обеспечивает аудит
– позволяет расследовать инциденты

Без него:
– нет postmortem
– нет SLO
– нет доверия к платформе

Итог

modules/observability — это:
– фундамент наблюдаемости
– vendor-agnostic
– platform-level
– обязательный для prod

### modules/observability/main.tf

Пояснение:
– каждый backend автономен
– можно заменить vendor
– единая точка подключения

### modules/observability/variables.tf

Пояснение:
– observability всегда env-specific
– retention = деньги + compliance

### modules/observability/outputs.tf

Пояснение:
– используется агентами
– используется GitOps
– единый контракт

### modules/observability/logging/

Централизованные логи инфраструктуры и кластера.

Решает:
– сбор
– хранение
– ретеншн

Не решает:
– парсинг бизнес-логики

Наполнение:
– backend: S3 / Object Storage
– lifecycle policy
– encryption
– access policy

#### modules/observability/logging/main.tf

Пояснение:
– immutable storage
– encryption by default
– audit-ready

### modules/observability/monitoring/

Backend для метрик.

Решает:
– хранение time-series
– retention
– HA

Наполнение:
– managed metrics backend
или
– object storage + remote write

#### modules/observability/monitoring/main.tf

Пояснение:
– decouple Prometheus от дисков
– масштабируемость
– disaster recovery

### modules/observability/tracing/

Backend для distributed tracing.

Решает:
– storage трейсов
– долгосрочное хранение
– анализ latency

Наполнение:
– object storage
– индекс
– retention

#### modules/observability/tracing/main.tf

Пояснение:
– Jaeger / Tempo не теряют данные
– дешёвое хранение
– масштаб без боли

---

# ci/

Автоматизация, контроль и защита Terraform до `apply`.

Состав:

- `terraform-validate.yml` — проверка форматирования и синтаксиса (`fmt`, `validate`) на корректность
- `terraform-plan.yml` — выполнение `plan` и сохранение артефактов для ревью на предмет того, что именно изменится
- `terraform-apply.yml` — применение изменений только из protected branch  
- `security-scan.yml` — статический анализ и политики безопасности (`tfsec`, `checkov`, `opa`)

Каждый файл = отдельный security gate.

Ни один change не должен:
– попасть в main без проверки
– примениться без ревью
– нарушить security / policy

Общая логика потока CI:
PR открыт
validate
plan
security
review
merge
apply

Если хоть один шаг падает —
infra не меняется.

DevSecOps-смысл CI

CI выполняет роль:
– policy enforcer
– security guard
– infra gatekeeper

Итог

ci/ — это:
– обязательный слой
– не опциональный
– не ускорение
– а защита

Без него Terraform = root-доступ.

## ci/terraform-validate.yml

Базовая техническая корректность.

Ловит:
– синтаксические ошибки
– некорректные провайдеры
– сломанные модули

Запускается на каждом PR.

Пояснения по шагам:

- `terraform fmt -check -recursive` — единый стиль, без форматного шума в PR, обязательная практика
- `terraform init -backend=false` — безопасно для PR, без доступа к backend и state
- `terraform validate` — проверка синтаксиса, модулей и базовой логики

Почему отдельный CI:
Validation ≠ Plan.  
Validation быстрый и дешёвый, должен падать первым.

## ci/terraform-plan.yml

Показывает что именно изменится.
Infra-review — как code-review.

Без plan:
– изменения вслепую
– невозможно оценить риск

Когда запускается:
– только PR
– до merge
– без apply

Пояснения по шагам:

- `permissions / id-token` — подготовка под OIDC, без long-lived secrets, enterprise-стандарт
- `terraform init` (with backend) — реальный state, план максимально близок к бою
- `terraform plan` — reviewer видит diff, инфраструктура становится читаемой

Почему без apply:
Plan — информация, не действие.  
Apply — только после контроля.

## ci/security-scan.yml

DevSecOps gate.
Ищет опасные паттерны, даже если Terraform валиден.

Ловит:
– public resources
– отсутствие encryption
– overly permissive IAM

Инструменты:
– tfsec
– checkov
– OPA (через `policies/opa`)

Это defense-in-depth, а не один сканер.

Пояснения:

- `tfsec` — быстрый, opinionated, первый барьер безопасности  
- `checkov` — enterprise rules, cloud-specific, compliance-ready  

Почему отдельный CI:
Security ≠ correctness.  
Должен развиваться отдельно, падать независимо и быть обязательным.

## ci/terraform-apply.yml

Единственная точка применения infra.

Apply:
– только из main
– только после merge
– только через CI

**Никакого terraform apply локально.**

Когда запускается:
– push в main
– после всех checks

Пояснения:

- Только `main` — защищённая ветка, PR + review обязательны  
- OIDC — CI identity, без секретов, audit-friendly  
- Auto-approve — повторное подтверждение не нужно, approval уже был в PR



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

Границы ответственности

modules/compute
– VM существуют

modules/security
– им разрешено общаться

modules/kubernetes
– VM становятся кластером

gitops/*
– кластер начинает жить