# Приклади конфігурацій мереж для Simple CNI

## 1. Стандартна конфігурація (10.244.0.0/16)

```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "bridge": "cni0",
  "mtu": 1500,
  "subnet": "10.244.0.0/16",
  "gateway": "10.244.0.1",
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/16",
    "gateway": "10.244.0.1"
  }
}
```

## 2. Альтернативна мережа (172.16.0.0/16)

```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "bridge": "cni0",
  "mtu": 1500,
  "subnet": "172.16.0.0/16",
  "gateway": "172.16.0.1",
  "ipam": {
    "type": "host-local",
    "subnet": "172.16.0.0/16",
    "gateway": "172.16.0.1"
  }
}
```

## 3. Менша мережа (192.168.1.0/24)

```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "bridge": "cni0",
  "mtu": 1500,
  "subnet": "192.168.1.0/24",
  "gateway": "192.168.1.1",
  "ipam": {
    "type": "host-local",
    "subnet": "192.168.1.0/24",
    "gateway": "192.168.1.1"
  }
}
```

## 4. Конфігурація з високим MTU

```json
{
  "cniVersion": "1.0.0",
  "name": "simple-cni",
  "type": "simple-cni",
  "bridge": "cni0",
  "mtu": 9000,
  "subnet": "10.244.0.0/16",
  "gateway": "10.244.0.1",
  "ipam": {
    "type": "host-local",
    "subnet": "10.244.0.0/16",
    "gateway": "10.244.0.1"
  }
}
```

## Використання з Helm

### Встановлення з кастомною мережею

```bash
helm install simple-cni ./helm \
  --namespace kube-system \
  --set cni.config.subnet="172.16.0.0/16" \
  --set cni.config.gateway="172.16.0.1" \
  --set cni.config.ipam.subnet="172.16.0.0/16" \
  --set cni.config.ipam.gateway="172.16.0.1"
```

### Оновлення існуючого розгортання

```bash
helm upgrade simple-cni ./helm \
  --namespace kube-system \
  --set cni.config.subnet="192.168.1.0/24" \
  --set cni.config.gateway="192.168.1.1"
```

## Перевірка конфігурації

### Перевірка поточної конфігурації

```bash
kubectl get configmap simple-cni-config -n kube-system -o yaml
```

### Тестування нової мережі

```bash
# Створити тестовий под
kubectl run test-pod --image=nginx

# Перевірити IP адресу
kubectl exec test-pod -- ip addr show

# Перевірити маршрути
kubectl exec test-pod -- ip route show
```

## Важливі зауваження

1. **Зміна мережі**: При зміні мережі потрібно перезапустити всі поди
2. **Конфлікти**: Переконайтеся, що нова мережа не конфліктує з існуючими
3. **Маршрутизація**: Налаштуйте маршрутизацію для нової мережі
4. **Брандмауер**: Оновіть правила брандмауера для нової мережі 