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

**2.2 Наполнение modules/compute/gpu/**

Выделенный GPU foundation-слой.
GPU — привилегированный ресурс, а не обычный compute.

Решает задачи:
- централизованное управление GPU-ресурсами
- изоляция GPU как отдельного trust-domain
- контроль доступа и масштабирования

**2.3 Наполнение modules/kubernetes/ai-node-pools/**

Выделенные node pools для AI-нагрузок.  
Жёсткое разделение CPU / GPU / general workloads.

Решает задачи:
- физическое разделение AI и general workloads
- изоляция GPU и CPU на уровне scheduler
- контроль размещения и масштабирования AI-нагрузок

**2.4 Наполнение modules/kubernetes/runtime-constraints/**

Жёсткие ограничения runtime-поведения AI-workloads.  
Даже при компрометации pod — минимальный ущерб.

**Решает задачи:**
- ограничение привилегий на уровне runtime
- централизованный контроль доступа к GPU
- устранение небезопасных ad-hoc runtime-настроек

**2.5 Наполнение policies/{opa,checkov,tfsec}/ai/**

Policy-as-Code для AI-инфраструктуры.  
Не «best practice», а enforcement.

**Решает задачи:**
- запрет опасных конфигураций на уровне AI-инфраструктуры
- обеспечение согласованности с foundation Terraform и ai/*, governance/*
- CI-blocking и audit-friendly enforcement

**2.5.1 Наполнение policies/opa/ai/**

Логическая политика для AI-инфраструктуры.  
Контекст-aware правила: intent, trust-zone, AI semantics.

**Решает задачи:**
- enforcement intent и trust-zone для AI workloads
- предотвращение обхода политик без явного override
- прозрачность security logic для reviewer

**2.5.2 Наполнение policies/checkov/ai/**

Static security checks для Terraform.  
Быстро, стандартизированно, автоматически.

**Решает задачи:**
- раннее выявление небезопасных конфигураций
- стандартизация security в Terraform
- снижение риска misconfiguration

**2.5.3 Наполнение policies/tfsec/ai/**

## policies/tfsec/ai/

Low-level detection misconfigurations в Terraform.  
Особенно полезен для storage и network.

**Решает задачи:**
- раннее выявление low-level misconfigurations
- защита storage и network в AI-инфраструктуре
- минимизация ошибок при deployment

**3. Sovereign AI слой (ai/*)**

Инфраструктурный слой AI-нагрузок: изолированное выполнение обучения и инференса, контролируемый доступ к данным и моделям, чёткое разделение data plane и compute plane для обеспечения суверенитета, воспроизводимости и управляемости AI-систем.

**3.1 Наполнение ai/network/**

AI-specific network restrictions поверх готовой network foundation.  
Управляет, куда AI workloads могут ходить, куда нет, и предотвращает data exfiltration.

**Решает задачи:**
- изоляция AI workloads на уровне сети
- контроль egress и предотвращение утечек данных
- разделение правил для training и inference

**3.2 Наполнение ai/data/**

Изоляция и защита datasets для AI.  
Управляет, где лежат данные, кто имеет доступ, предотвращает утечки и обеспечивает соответствие sovereign-требованиям.

**Решает задачи:**
- изоляция AI-данных от infra и кода
- контроль доступа и предотвращение утечек
- enforce mandatory encryption и lifecycle
- подготовка контрактов для training / inference

**3.3 Наполнение ai/model-registry/**

Защита и изоляция AI-моделей как интеллектуального актива.  
Управляет, где хранятся модели, кто может читать/публиковать, предотвращает утечки и отделяет training от inference.

**Решает задачи:**
- изоляция моделей от infra, данных и кода
- контроль publish vs consume → предотвращение утечек
- enforce mandatory encryption и versioning
- подготовка контрактов для inference

**3.4. Наполнение ai/training/**

Изолированная training-зона для AI.  
Управляет, где выполняется обучение, кто может запускать training, какие ресурсы разрешены и предотвращает утечки данных и моделей.

**Решает задачи:**
- изоляция training как зоны повышенного риска
- контроль использования GPU, CPU и памяти
- предотвращение утечек данных и моделей
- подготовка безопасной execution-среды

**3.5 Наполнение ai/inference/**

Безопасный inference-serving для AI-моделей.  
Управляет публикацией моделей, кто может вызывать inference, runtime-ограничениями и предотвращает утечки моделей и данных.

**Решает задачи:**
- изоляция inference от training  
- ограничение публичного доступа  
- runtime hardening и exploit resistance  
- подготовка controlled serving environment

**4. Sovereign AI слой Governance/enforcement (governance/*)**

Слой управления и принудительного контроля: политики, ограничения и проверки, обеспечивающие соответствие требованиям безопасности, комплаенса и суверенитета, с централизованным enforcement-уровнем для AI-инфраструктуры и процессов.

**4.1 Наполнение governance/policy-as-code/**

Централизованное Security и Governance управление Sovereign AI.  
Определяет, какие AI-конфигурации разрешены, какие запрещены, как политика enforced и как платформа доказывает compliance.

**Решает задачи:**
- формализация допустимых и запрещённых AI-паттернов  
- централизованный enforcement политик  
- CI-блокировка merge и apply  
- единые правила для dev и prod

**4.1.1 Наполнение governance/policy-as-code/opa/**

**4.1.2 Наполнение governance/policy-as-code/terraform/**

Terraform-уровень governance.  
Глобальные жёсткие запреты, не зависящие от AI-логики и Kubernetes.

**Решает задачи:**
- фиксация красных линий (encryption, public access, region)  
- enforcement sovereign-требований на уровне Terraform plan  
- остановка ошибки до создания ресурса  
- одинаковое применение для всех окружений  

**4.1.3 Наполнение governance/policy-as-code/ci/**

CI-уровень enforcement политик.  
Никакого merge без прохождения governance.  

**Решает задачи:**
- превращает политики в merge-gate  
- исключает человеческий фактор  
- обеспечивает непрерывный аудит  
- блокирует небезопасные изменения до merge  




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

### governance/
Управление и принудительный контроль.
- `policy-as-code/` — формализует правила, исключения и аудит для AI-инфраструктуры
- `audit-rules/` — правила аудита действий и изменений в AI-инфраструктуре  
- `exception-workflows/` — процессы обработки и одобрения отклонений от стандартных политик  
- `compliance-mappings/` — соответствие между корпоративными требованиями, регуляторными нормами и реализацией инфраструктуры  
- `decision-logs/` — хранение результатов проверок, принятых решений и действий enforcement

### .terraform-version
Фиксация версии Terraform. Репродуцируемость.

---

### Итог
Полная картина enterprise Terraform:
- global — фундамент
- modules — логика
- environments — конфигурация
- policies + ci — DevSecOps защита