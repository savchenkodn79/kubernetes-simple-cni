#!/bin/bash

set -e

echo "🔍 Перевірка встановлення Simple CNI"

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

# Перевірка статусу подів
log "📋 Перевірка статусу подів..."
kubectl get pods -n kube-system -l app=simple-cni

# Перевірка логів
log "📋 Перевірка логів..."
kubectl logs -n kube-system -l app=simple-cni --tail=20

# Перевірка DaemonSet
log "📋 Перевірка DaemonSet..."
kubectl describe daemonset simple-cni -n kube-system

# Перевірка бінарного файлу на вузлах
log "📋 Перевірка бінарного файлу на вузлах..."
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    log "Перевірка вузла: $node"
    kubectl debug node/$node -it --image=alpine -- chroot /host ls -la /usr/local/bin/simple-cni 2>/dev/null || warn "Бінарний файл не знайдено на вузлі $node"
done

# Перевірка конфігурації CNI
log "📋 Перевірка конфігурації CNI..."
kubectl get configmap simple-cni-config -n kube-system -o yaml

# Тестування CNI
log "📋 Тестування CNI..."
kubectl run test-cni --image=nginx --rm -it --restart=Never -- sh -c "ip addr show && ip route show" 2>/dev/null || warn "Не вдалося протестувати CNI"

log "✅ Перевірка завершена!" 