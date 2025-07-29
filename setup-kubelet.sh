#!/bin/bash

set -e

echo "🔧 Налаштування kubelet для Simple CNI"

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

# Функція для налаштування вузла
setup_node() {
    local node_name=$1
    
    log "Налаштування вузла: $node_name"
    
    # Копіюємо конфігурацію CNI на вузол
    kubectl debug node/$node_name -it --image=alpine -- chroot /host mkdir -p /etc/cni/net.d
    
    # Копіюємо конфігурацію simple-cni
    cat > /tmp/10-simple-cni.conf << EOF
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
EOF
    
    kubectl cp /tmp/10-simple-cni.conf $node_name:/etc/cni/net.d/10-simple-cni.conf -c debug
    
    # Копіюємо loopback конфігурацію
    cat > /tmp/99-loopback.conf << EOF
{
  "cniVersion": "1.0.0",
  "name": "loopback",
  "type": "loopback"
}
EOF
    
    kubectl cp /tmp/99-loopback.conf $node_name:/etc/cni/net.d/99-loopback.conf -c debug
    
    # Перевіряємо конфігурацію kubelet
    log "Перевірка конфігурації kubelet..."
    kubectl debug node/$node_name -it --image=alpine -- chroot /host cat /var/lib/kubelet/config.yaml | grep -E "(cni|network)" || warn "CNI налаштування не знайдено в kubelet"
    
    # Очищаємо тимчасові файли
    rm -f /tmp/10-simple-cni.conf /tmp/99-loopback.conf
    
    log "✅ Вузол $node_name налаштовано"
}

# Головна функція
main() {
    log "🔍 Отримання списку вузлів..."
    
    # Отримуємо список вузлів
    nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    if [ -z "$nodes" ]; then
        error "Не знайдено вузлів в кластері"
        exit 1
    fi
    
    log "Знайдено вузлів: $(echo $nodes | wc -w)"
    
    # Налаштовуємо кожен вузол
    for node in $nodes; do
        setup_node $node
    done
    
    log "🎉 Всі вузли налаштовано!"
    log "Тепер можна тестувати CNI:"
    echo "  kubectl run test-pod --image=nginx"
    echo "  kubectl exec test-pod -- ip addr show"
}

# Запускаємо головну функцію
main "$@" 