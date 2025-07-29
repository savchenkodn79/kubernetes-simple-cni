#!/bin/bash

set -e

# Кольори для виводу
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функція для тестування мережі
test_network() {
    local subnet=$1
    local gateway=$2
    local name=$3
    
    log "Тестування мережі: $name ($subnet)"
    
    # Створюємо тимчасовий ConfigMap
    cat > /tmp/test-cni-config.json << EOF
{
  "cniVersion": "1.0.0",
  "name": "test-cni",
  "type": "simple-cni",
  "subnet": "$subnet",
  "gateway": "$gateway",
  "mtu": 1500,
  "bridge": "cni0"
}
EOF
    
    # Застосовуємо конфігурацію
    kubectl create configmap test-cni-config --from-file=10-test-cni.conf=/tmp/test-cni-config.json -n kube-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Створюємо тестовий под
    kubectl run test-pod-$name --image=nginx --overrides='{
      "spec": {
        "nodeSelector": {
          "kubernetes.io/hostname": "'$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')'"
        }
      }
    }'
    
    # Чекаємо поки под запуститься
    kubectl wait --for=condition=ready pod/test-pod-$name --timeout=60s
    
    # Перевіряємо IP адресу
    log "IP адреса поду:"
    kubectl exec test-pod-$name -- ip addr show eth0
    
    # Перевіряємо маршрути
    log "Маршрути поду:"
    kubectl exec test-pod-$name -- ip route show
    
    # Тестуємо з'єднання
    log "Тестування з'єднання:"
    kubectl exec test-pod-$name -- ping -c 3 $gateway
    
    # Видаляємо тестовий под
    kubectl delete pod test-pod-$name
    
    log "✅ Тест мережі $name завершено"
    echo "---"
}

# Головна функція
main() {
    log "🧪 Тестування різних конфігурацій мереж"
    
    # Перевіряємо чи працює кластер
    if ! kubectl cluster-info &> /dev/null; then
        error "Kubernetes кластер недоступний"
        exit 1
    fi
    
    # Тестуємо різні мережі
    test_network "10.244.0.0/16" "10.244.0.1" "default"
    test_network "172.16.0.0/16" "172.16.0.1" "alternative"
    test_network "192.168.1.0/24" "192.168.1.1" "small"
    
    # Очищаємо тимчасові файли
    rm -f /tmp/test-cni-config.json
    
    log "🎉 Всі тести завершено успішно!"
}

# Запускаємо головну функцію
main "$@" 