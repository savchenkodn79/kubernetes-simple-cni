# Інструкції по розгортанню Simple CNI

## Швидкий старт

### 1. Автоматичне розгортання

```bash
# Зробити скрипт виконуваним
chmod +x build-and-deploy.sh

# Запустити збірку та розгортання
./build-and-deploy.sh
```

### 2. Ручне розгортання

#### Крок 1: Збірка Docker образу

```bash
docker build -t simple-cni:latest .
```

#### Крок 2: Розгортання через Helm (рекомендовано)

```bash
# Створити namespace
kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -

# Розгорнути через Helm
helm install simple-cni ./helm \
    --namespace kube-system \
    --set image.repository=simple-cni \
    --set image.tag=latest \
    --set image.pullPolicy=IfNotPresent
```

#### Крок 3: Розгортання через YAML файли

```bash
# Застосувати RBAC
kubectl apply -f k8s/rbac.yaml

# Застосувати конфігурацію CNI
kubectl apply -f k8s/cni-config.yaml

# Застосувати DaemonSet
kubectl apply -f k8s/daemonset.yaml
```

## Перевірка розгортання

### Перевірка статусу подів

```bash
kubectl get pods -n kube-system -l app=simple-cni
```

### Перегляд логів

```bash
kubectl logs -n kube-system -l app=simple-cni
```

### Детальна інформація про DaemonSet

```bash
kubectl describe daemonset simple-cni -n kube-system
```

## Налаштування як основного CNI

### 1. Перевірка поточної конфігурації kubelet

```bash
kubectl get nodes -o yaml | grep -A 10 kubelet
```

### 2. Налаштування kubelet для використання simple-cni

На кожному вузлі кластера відредагуйте конфігурацію kubelet:

```bash
# На вузлі кластера
sudo vi /var/lib/kubelet/config.yaml
```

Додайте або змініть:

```yaml
cniConfDir: /etc/cni/net.d
cniBinDir: /opt/cni/bin
networkPlugin: cni
```

### 3. Перезапуск kubelet

```bash
sudo systemctl restart kubelet
```

## Структура проекту

```
eBPF-k8s/
├── simple-cni.go          # Основний код CNI
├── Dockerfile             # Збірка Docker образу
├── go.mod                 # Go залежності
├── build-and-deploy.sh    # Скрипт збірки та розгортання
├── k8s/                   # YAML файли для Kubernetes
│   ├── daemonset.yaml
│   ├── rbac.yaml
│   └── cni-config.yaml
├── helm/                  # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
└── README.md              # Документація
```

## Принцип роботи CNI

### 1. Життєвий цикл поду

1. **Створення поду**: Kubernetes створює под
2. **Виклик CNI**: kubelet викликає CNI бінарний файл з командою `ADD`
3. **Створення мережі**: CNI створює veth пару та налаштовує мережу
4. **Повернення результату**: CNI повертає конфігурацію мережі
5. **Видалення поду**: При видаленні поду викликається команда `DEL`

### 2. Команди CNI

- `ADD`: Додає под до мережі
- `DEL`: Видаляє под з мережі  
- `CHECK`: Перевіряє стан мережі

### 3. Вхідні дані CNI

CNI отримує через змінні середовища:
- `CNI_COMMAND`: Команда (ADD/DEL/CHECK)
- `CNI_CONTAINERID`: ID контейнера
- `CNI_NETNS`: Шлях до мережевого простору імен
- `CNI_IFNAME`: Назва інтерфейсу
- `CNI_ARGS`: Додаткові аргументи

## Відлагодження

### Перевірка логів CNI

```bash
# Логи DaemonSet
kubectl logs -n kube-system -l app=simple-cni

# Логи конкретного поду
kubectl logs -n kube-system <pod-name>
```

### Перевірка мережевих інтерфейсів

```bash
# На вузлі кластера
ip link show
ip addr show
```

### Тестування CNI

```bash
# Створити тестовий под
kubectl run test-pod --image=nginx

# Перевірити мережу
kubectl exec test-pod -- ip addr show
kubectl exec test-pod -- ip route show
```

## Видалення

### Видалення через Helm

```bash
helm uninstall simple-cni -n kube-system
```

### Видалення через kubectl

```bash
kubectl delete -f k8s/daemonset.yaml
kubectl delete -f k8s/cni-config.yaml
kubectl delete -f k8s/rbac.yaml
```

## Відомі проблеми

1. **Привілейований режим**: CNI потребує привілейованого доступу
2. **Host Network**: DaemonSet використовує host network
3. **Tolerations**: Потрібні tolerations для master вузлів

## Розширення

Для розширення функціональності:

1. Додайте підтримку IPAM
2. Реалізуйте підтримку різних типів мереж
3. Додайте метрики та моніторинг
4. Реалізуйте підтримку IPv6 