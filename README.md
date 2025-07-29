# Простий CNI для Kubernetes

Цей проект демонструє як створити власну CNI (Container Network Interface) для Kubernetes.

## Що таке CNI?

CNI (Container Network Interface) - це специфікація та набір бібліотек для налаштування мережевих інтерфейсів у контейнерах. Kubernetes використовує CNI для підключення подів до мережі.

## Структура проекту

- `simple-cni.go` - основний код CNI
- `Dockerfile` - збірка Docker образу
- `go.mod` - Go залежності
- `build-and-deploy.sh` - скрипт збірки та розгортання
- `test-network.sh` - скрипт тестування різних мереж
- `k8s/` - YAML файли для Kubernetes
  - `daemonset.yaml` - DaemonSet для розгортання
  - `rbac.yaml` - RBAC ресурси
  - `cni-config.yaml` - конфігурація CNI
- `helm/` - Helm chart
  - `Chart.yaml` - метадані chart
  - `values.yaml` - значення за замовчуванням
  - `templates/` - шаблони ресурсів
- `examples/` - приклади конфігурацій
  - `network-configs.md` - приклади різних мереж

## Як використовувати

### Швидкий старт

1. **Автоматичне розгортання:**
   ```bash
   chmod +x build-and-deploy.sh
   ./build-and-deploy.sh
   ```

2. **Локальна збірка (без Docker):**
   ```bash
   chmod +x build-local.sh
   ./build-local.sh
   ```

3. **Перевірка встановлення:**
   ```bash
   chmod +x check-installation.sh
   ./check-installation.sh
   ```

### Ручне розгортання

1. **Збірка Docker образу:**
   ```bash
   docker build -t simple-cni:latest .
   ```

2. **Розгортання через Helm:**
   ```bash
   helm install simple-cni ./helm --namespace kube-system
   ```

3. **Розгортання через YAML:**
   ```bash
   kubectl apply -f k8s/rbac.yaml
   kubectl apply -f k8s/cni-config.yaml
   kubectl apply -f k8s/daemonset-init.yaml
   ```

## Принцип роботи

1. Kubernetes викликає CNI бінарний файл з командами ADD/DEL
2. CNI отримує конфігурацію та інформацію про контейнер
3. CNI створює/видаляє мережевий інтерфейс
4. Повертає результат операції

## Налаштування мережі

CNI підтримує гнучке налаштування мережі через конфігурацію:

### Параметри конфігурації

- `subnet`: Підмережа для подів (наприклад, "10.244.0.0/16")
- `gateway`: Шлюз за замовчуванням (наприклад, "10.244.0.1")
- `mtu`: Максимальний розмір пакету (за замовчуванням 1500)
- `bridge`: Назва мосту (за замовчуванням "cni0")

### Приклад конфігурації

```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "subnet": "172.16.0.0/16",
  "gateway": "172.16.0.1",
  "mtu": 1500,
  "bridge": "cni0"
}
```

### Встановлення з кастомною мережею

```bash
helm install simple-cni ./helm \
  --namespace kube-system \
  --set cni.config.subnet="172.16.0.0/16" \
  --set cni.config.gateway="172.16.0.1"
``` 