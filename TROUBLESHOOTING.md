# Виправлення проблем (Troubleshooting)

## Поширені проблеми та їх вирішення

### 1. Помилка "no such file or directory" при запуску контейнера

**Симптоми:**
```
Error: container create failed: exec: "/opt/cni/bin/simple-cni": stat /opt/cni/bin/simple-cni: no such file or directory
```

**Рішення:**
- Використовуйте `daemonset-init.yaml` замість `daemonset.yaml`
- InitContainer скопіює бінарний файл на хост
- Перевірте, чи правильно зібрано Docker образ

### 2. Помилка збірки Docker "go.sum not found"

**Симптоми:**
```
ERROR: failed to build: failed to solve: failed to compute cache key: failed to calculate checksum of ref: "/go.sum": not found
```

**Рішення:**
- Використовуйте `build-local.sh` для локальної збірки
- Або оновлений Dockerfile автоматично створить go.sum

### 3. Поди не запускаються

**Симптоми:**
```
kubectl get pods -n kube-system -l app=simple-cni
# Поди в стані Pending або Error
```

**Рішення:**
- Перевірте tolerations для master вузлів
- Переконайтеся, що ServiceAccount створено
- Перевірте RBAC права

### 4. CNI не працює для нових подів

**Симптоми:**
```
kubectl run test-pod --image=nginx
# Под не отримує IP адресу
```

**Рішення:**
- Перевірте конфігурацію kubelet
- Переконайтеся, що CNI бінарний файл доступний
- Перевірте конфігурацію в `/etc/cni/net.d/`

### 5. Помилки мережевих інтерфейсів

**Симптоми:**
```
Warning: failed to execute ip link add
```

**Рішення:**
- Переконайтеся, що контейнер має привілеї NET_ADMIN
- Перевірте, чи встановлені мережеві інструменти в образі

## Команди для діагностики

### Перевірка статусу розгортання

```bash
# Перевірка подів
kubectl get pods -n kube-system -l app=simple-cni

# Перегляд логів
kubectl logs -n kube-system -l app=simple-cni

# Детальна інформація про DaemonSet
kubectl describe daemonset simple-cni -n kube-system
```

### Перевірка бінарного файлу

```bash
# Перевірка на вузлі
kubectl debug node/<node-name> -it --image=alpine -- chroot /host ls -la /usr/local/bin/simple-cni

# Тестування бінарного файлу
kubectl debug node/<node-name> -it --image=alpine -- chroot /host /usr/local/bin/simple-cni --help
```

### Перевірка конфігурації

```bash
# Перевірка ConfigMap
kubectl get configmap simple-cni-config -n kube-system -o yaml

# Перевірка на вузлі
kubectl debug node/<node-name> -it --image=alpine -- chroot /host cat /etc/cni/net.d/10-simple-cni.conf
```

### Тестування CNI

```bash
# Створення тестового поду
kubectl run test-pod --image=nginx --rm -it --restart=Never -- sh

# Перевірка мережі в поді
ip addr show
ip route show
ping -c 3 8.8.8.8
```

## Відновлення після збою

### Повне перезапуск

```bash
# Видалення старого розгортання
kubectl delete -f k8s/daemonset-init.yaml
kubectl delete -f k8s/cni-config.yaml
kubectl delete -f k8s/rbac.yaml

# Перезапуск
kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/cni-config.yaml
kubectl apply -f k8s/daemonset-init.yaml
```

### Очищення вузлів

```bash
# Видалення бінарних файлів з вузлів
kubectl debug node/<node-name> -it --image=alpine -- chroot /host rm -f /usr/local/bin/simple-cni

# Перезапуск DaemonSet
kubectl rollout restart daemonset simple-cni -n kube-system
```

## Логування та відлагодження

### Увімкнення детального логування

Додайте в конфігурацію CNI:
```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "logLevel": "debug"
}
```

### Перегляд логів kubelet

```bash
# На вузлі кластера
sudo journalctl -u kubelet -f
```

### Перевірка CNI викликів

```bash
# Перегляд логів CNI
kubectl logs -n kube-system -l app=simple-cni -f
``` 