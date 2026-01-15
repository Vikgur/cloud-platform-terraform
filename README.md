# О проекте

Этот репозиторий — эталонная архитектура Terraform для enterprise-уровня на базе AWS. Он показывает, как с нуля спроектировать cloud-platform под Kubernetes (3 master / 50+ worker) с упором на безопасность, масштабируемость и управляемость.

**Реализованы принципы best practice:**

- Жёсткое разделение слоёв: `global` → `modules` → `environments`.
- Один модуль = одна ответственность.
- Remote state с изоляцией по окружениям.
- Immutable инфраструктура: пересоздание compute без side-effects.
- Predictable scaling: контроль автоскейлинга и планируемого роста.
- No snowflake nodes: все мастер и воркер-ноды унифицированы.
- Blast radius control: ошибки изолированы по зонам ответственности.
- Чёткое разделение master / worker для безопасности и стабильности.
- Policy-as-code и DevSecOps: OPA, tfsec, Checkov, аудит.
- Подготовка под GitOps: CI/CD, multi-env, управляемый rollout.
- Безопасное управление секретами, ключами, state и sensitive files.
- Growth-ready: поддержка сотен нод без рефакторинга архитектуры.

**Этапы реализации:**

1. Проектирование архитектуры 

Фундамент планирования.
Практическая реализация: скрипт `scrips/architecture_bootstrap.sh`

2. Инфраструктура для хранения 

Наполнение `global/` – секрет уровня infra-root.

Решает задачи:
- Централизованное хранение state
- Блокировка параллельных apply
- Шифрование
- Аудит доступа

3. Переиспользуемая бизнес-логика

`modules/` – основа всего проекта.

3.1 Наполнение `modules/shared` 

Вспомогательные абстракции.

Решает задачи:
- Единые имена ресурсов
- Единые теги
- Единые labels
- Единые locals

Без shared-модуля:
- Хаос
- Невозможный аудит
- Плохой DevSecOps и incident response

3.2 Наполнение `modules/network`

Сетевой необратимый фундамент.

Решает задачи:
- Изоляция окружений
- Control / data plane separation
- Ingress / egress контроль
- Blast radius (Взлом ноды = доступ к pod secrets, lateral movement, takeover всего кластера)
- Zero-trust основу

Без network-модуля:
- Security невозможна
- Kubernetes нестабилен

3.3 Наполнение `modules/security`

Сетевая и perimeter-безопасность.

Решает задачи:
- Кто с кем может общаться
- Откуда возможен ingress
- Куда разрешён egress
- Минимизацию attack surface

Security-модуль — это:
- Формализация доверия
- Основа zero-trust
- Обязательный слой перед compute и k8s

3.4 Наполнение `modules/compute`

Виртуальные машины и scaling. Отвечает только за вычислительные ресурсы. 

Решает задачи:
– сколько нод
– какого типа
– как они масштабируются
– как они пересоздаются

Compute-модуль — это:
– управляемая мощность
– без бизнес-логики
– до Kubernetes

3.5 Наполнение `modules/kubernetes`




4. 







# Структура

### README.md
Точка входа.  
Как работать с репозиторием, порядок деплоя, правила.

### docs/
Документация как часть инфраструктуры.
- architecture.md — общая схема и границы модулей
- security-model.md — threat model, IAM, сети, trust boundaries
- state-backend.md — хранение state, locking, шифрование
- workflows.md — CI/CD сценарии, plan/apply

### global/
Общие ресурсы организации. Создаются один раз.
- backend/ — S3 + DynamoDB + KMS для state
- iam/ — роли и политики Terraform
- org-policies/ — guardrails и quotas уровня компании

### modules/
Переиспользуемая бизнес-логика.
- network/ — VPC, subnets, NAT, routing
- security/ — SG, NSG, firewall
- compute/ — master, worker, autoscaling
- kubernetes/ — control-plane, node-groups, CNI, bootstrap
- storage/ — block, object, backups
- observability/ — logging, monitoring, tracing
- access/ — IAM, OIDC, RBAC
- shared/ — naming, labels, tags, locals

### environments/
Конкретные окружения. Только wiring.
- dev/
- stage/
- prod/

Важно:
- Никаких ресурсов напрямую.
- Только вызовы модулей.

### policies/
DevSecOps контроль.
- opa/ — запреты и guardrails
- tfsec/ — security scanning
- checkov/ — compliance

### ci/
CI/CD пайплайны.
- validate — fmt, validate
- plan — plan + artifacts
- apply — apply из protected branch
- security-scan — tfsec, checkov, opa

### scripts/
Локальная эргономика.
- init.sh — terraform init
- plan.sh — стандартный plan
- apply.sh — контролируемый apply
- architecture_bootstrap.sh — создание структуры каталогов проекта

### .terraform-version
Фиксация версии Terraform. Репродуцируемость.

---

### Итог
Полная картина enterprise Terraform:
- global — фундамент
- modules — логика
- environments — конфигурация
- policies + ci — DevSecOps защита