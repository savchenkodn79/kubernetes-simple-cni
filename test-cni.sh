#!/bin/bash

set -e

echo "🧪 Тестування Simple CNI"

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

# Функція для тестування CNI
test_cni() {
    local command=$1
    local container_id=$2
    local netns=$3
    local ifname=$4
    
    log "Тестування CNI команди: $command"
    
    # Створюємо тимчасовий файл конфігурації
    cat > /tmp/test-cni-config.json << EOF
{
  "cniVersion": "1.0.0",
  "name": "test-cni",
  "type": "simple-cni",
  "subnet": "10.244.0.0/16",
  "gateway": "10.244.0.1",
  "mtu": 1500,
  "bridge": "cni0"
}
EOF
    
    # Встановлюємо змінні середовища
    export CNI_COMMAND=$command
    export CNI_CONTAINERID=$container_id
    export CNI_NETNS=$netns
    export CNI_IFNAME=$ifname
    export CNI_ARGS=""
    export CNI_PATH="/opt/cni/bin"
    
    # Викликаємо CNI
    echo "Виклик: $command $container_id $netns $ifname"
    cat /tmp/test-cni-config.json | ./simple-cni $command $container_id $netns $ifname
    
    # Очищаємо
    rm -f /tmp/test-cni-config.json
}

# Головна функція
main() {
    log "🔨 Збірка CNI..."
    go build -o simple-cni simple-cni.go
    
    if [ ! -f "./simple-cni" ]; then
        error "Не вдалося зібрати CNI"
        exit 1
    fi
    
    log "✅ CNI зібрано успішно"
    
    # Тестуємо різні команди
    test_cni "add" "test-container-123" "/proc/1/ns/net" "eth0"
    test_cni "del" "test-container-123" "/proc/1/ns/net" "eth0"
    test_cni "check" "test-container-123" "/proc/1/ns/net" "eth0"
    
    log "🎉 Тестування завершено!"
}

# Запускаємо головну функцію
main "$@" 