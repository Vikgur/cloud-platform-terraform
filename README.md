Принцип взаимосвязи в docs/:
architecture.md — обзор, точка входа
security-model.md — концептуальные угрозы + контролы
state-backend.md + workflows.md — lifecycle infra, state, promotion
break-glass.md — экстренный доступ
data-flows.md — визуализация потоков данных, с ссылками на контролы и workflow

---

What problem this platform solves
How a senior DevSecOps uses it
What risks it mitigates

Инженерное решение:
reference CI implemented
real execution demonstrated in GitHub Actions (health-api)
stages and controls are equivalent

---

# О проекте

Этот репозиторий — эталонная архитектура Terraform для enterprise-уровня на базе AWS. Он показывает, как с нуля спроектировать IaC cloud-platform под Kubernetes (3 master / 50+ worker) с упором на безопасность, масштабируемость и управляемость.

Ключевые акценты DevSecOps
– Remote backend + locking
– IAM least privilege
– OPA / Checkov / tfsec обязательны
– Полная изоляция state по environment
– CI запрещает apply без review

Чеклист корректной архитектуры
– Нет ресурсов в root
– Все ресурсы через modules
– Environments не содержат логики
– Security и access — отдельные домены
– Подготовка под GitOps (например ArgoCD)

Эта структура закрывает:
– масштаб (50+ нод → 500+)
– безопасность
– аудит
– прод без переделок

**Реализованы принципы best practice:**

- Реализована двухуровневая архитектура модулей:
    - L2-модуль (агрегирующий)
    - L3-модули (атомарные, переиспользуемые)
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
- Kubernetes разворачивается на уровне Terraform: инициализация control-plane и worker-нод происходит автоматически при создании `compute`, до применения Ansible.

**Реализованное наполнение репозитория:**

L2-модули (реализовано):
– описывают архитектуру целиком  
– оркестрируют L3  
– экспортируют единые outputs  

L3-модули (частично реализовано):
– делают конкретные задачи  
– не знают о всей системе  
– максимально переиспользуемы  

Пример: для демонстрации enterprise-L3 практик полностью наполнены только модули `modules/access` и `modules/observability`. Остальные L3-модули запланированы к реализации в будущем.

---

# Этапы реализации наполнения

Структура репозитория построена с учетом переиспользования базовой инфраструктуры: сначала создана общая Terraform-архитектура без слоя Sovereign AI, затем интегрирован `Sovereign AI` как отдельный модульный слой. 

Такой подход отражает паттерн **reusable infra**, позволяя адаптивно масштабировать и применять архитектуру для разных проектов и требований.

## 1 этап: ДО внедрения Sovereign AI-слоя

Базовая Terraform-архитектура cloud-platform для enterprise-уровня на AWS: проектирование и развертывание Kubernetes-кластера (3 master / 50+ worker) с упором на безопасность, масштабируемость, отказоустойчивость и управляемость, без AI-специфичных доменов, но с готовностью к расширению.

**1. Cкрипт `scrips/architecture_bootstrap.sh`**

Проектирование архитектуры. Фундамент планирования.

Решает задачи:
- Наполнение репозитория директориями/файлами.
- Автоматизация с использованием bash

**2. Наполнение `global/`**

Инфраструктура для хранения. Секрет уровня infra-root.

Назначение: общие ресурсы организации. Создаются один раз.

Решает задачи:
- Централизованное хранение state
- Блокировка параллельных apply
- Шифрование
- Аудит доступа

**3. Наполнение `modules/`**

Переиспользуемая бизнес-логика. Основа всего проекта.

**3.1 Наполнение `modules/shared`**

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

**3.2 Наполнение `modules/network`**

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

**3.3 Наполнение `modules/security`**

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

**3.4 Наполнение `modules/compute`**

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

**3.5 Наполнение `modules/kubernetes`**

Kubernetes-уровень. 

Решает задачи:
- Bootstrap k3s.
- Что считается кластером
- Где граница ответственности
- Как формируется control-plane
- Как ноды становятся кластером
- Какие базовые компоненты обязательны

Kubernetes-модуль это:
– кластер как infra-object
– воспроизводимый bootstrap
– чёткая граница Terraform / Ansible
– zero-click join нод

**3.6 Наполнение `modules/access`**

Слой идентификации и управления доступом.

Решает задачи:
- Связывает Cloud IAM, OIDC/SSO и Kubernetes RBAC  
- Убирает статические секреты и вводит federated trust  
- Разделяет ответственность: cloud ≠ k8s ≠ human access  
- Экспортирует идентификаторы и конфигурации для CI/CD и GitOps  
- Формирует enterprise-identity слой как основу DevSecOps

**3.7 Наполнение `modules/observability`**

Инфраструктурный слой наблюдаемости.

Решает задачи:
- Определяет, где хранятся логи, метрики и трейсы
- Собирать и стандартизировать backend-агрегаторы данных наблюдаемости
- Экспортировать endpoints для CI/CD и GitOps
- Обеспечивает аудит и расследование инцидентов
- Формирует фундамент observability на уровне платформы, независимый от конкретных приложений

**4. Наполнениеи `ci/`**

Автоматизация, контроль и защита Terraform до `apply`.

Решает задачи:
- Не допускает попадание изменений в `main` без проверки
- Исключает применение инфраструктуры без ревью
- Предотвращает нарушения security и policy
- Делает изменения инфраструктуры воспроизводимыми и аудируемыми
- Фиксирует, что именно и почему меняется до фактического `apply`

**5. Наполнение `policies/`**

Policy-as-code слой. Отвечает не за безопасность как таковую, а за соответствие внутренним правилам и стандартам компании.

Решает задачи:
- Что запрещено в нашей организации (политики OPA)
- Управляет правилами сканирования

**6. Наполнение `scripts/`**

Операционная автоматизация Terraform и инфраструктуры.

Решает задачи:
– bootstrapping backend
– подготовка окружения
– унифицированный plan/apply workflow
– безопасное применение изменений

---

## 2 этап: внедрение Sovereign AI-слоя

Поверх базовой платформы добавляется модульный Sovereign AI-слой: изолированные AI-нагрузки, разделение data / training / inference / CI, governance и enforcement-механизмы, обеспечивающие суверенитет данных, минимальный blast radius и соответствие enterprise-требованиям к безопасности и комплаенсу.

**1. Cкрипт `scrips/ai_architecture_bootstrap.sh`**

Проектирование архитектуры поддержки Sovereign AI-слоя. Фундамент планирования.

Решает задачи:
- Наполнение репозитория дополнительными директориями/файлами.
- Автоматизация с использованием bash

**2. Foundation-расширения для AI**

Базовый слой IAM и инфраструктурных примитивов для AI-нагрузок: строгая сегрегация ролей и доступов между данными, обучением, инференсом и CI, минимизация blast radius и отсутствие shared-roles как обязательное условие безопасного и масштабируемого AI-стека.

**2.1 Наполнение global/iam/ai-roles/**

AI-специфичные IAM-роли.

Решает задачи:
- жёсткое разделение data / training / inference / CI
- минимальный blast radius
- отсутствие shared-roles

**2.2 modules/compute/gpu/**

Выделенный GPU foundation-слой.
GPU — привилегированный ресурс, а не обычный compute.

Решает задачи:
- централизованное управление GPU-ресурсами
- изоляция GPU как отдельного trust-domain
- контроль доступа и масштабирования

**2.3 modules/kubernetes/ai-node-pools/**


**2.4 modules/kubernetes/runtime-constraints/**


**2.5 policies/{opa,checkov,tfsec}/ai/**



**3. Sovereign AI слой (ai/*)**

Инфраструктурный слой AI-нагрузок: изолированное выполнение обучения и инференса, контролируемый доступ к данным и моделям, чёткое разделение data plane и compute plane для обеспечения суверенитета, воспроизводимости и управляемости AI-систем.

**4. Sovereign AI слой Governance/enforcement (governance/*)**

Слой управления и принудительного контроля: политики, ограничения и проверки, обеспечивающие соответствие требованиям безопасности, комплаенса и суверенитета, с централизованным enforcement-уровнем для AI-инфраструктуры и процессов.







---

# Структура (ДОПОЛНИТЬ И АКТУАЛИЗИРОВАТЬ)

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
- ai_architecture_bootstrap.sh — добавление каталогов проекта под AI


### .terraform-version
Фиксация версии Terraform. Репродуцируемость.

---

### Итог
Полная картина enterprise Terraform:
- global — фундамент
- modules — логика
- environments — конфигурация
- policies + ci — DevSecOps защита