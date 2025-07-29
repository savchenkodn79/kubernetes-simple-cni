#!/bin/bash

set -e

echo "🔨 Локальна збірка Simple CNI"

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

# Перевіряємо чи встановлений Go
if ! command -v go &> /dev/null; then
    error "Go не встановлений. Будь ласка, встановіть Go."
    exit 1
fi

log "📦 Завантаження залежностей..."
go mod tidy

log "🔨 Збірка бінарного файлу..."
go build -o simple-cni simple-cni.go

if [ $? -eq 0 ]; then
    log "✅ Бінарний файл успішно зібрано: simple-cni"
    
    # Показуємо інформацію про бінарний файл
    log "📋 Інформація про бінарний файл:"
    ls -la simple-cni
    file simple-cni
    
    log "🧪 Тестування бінарного файлу..."
    ./simple-cni --help 2>/dev/null || echo "Бінарний файл готовий до використання"
    
    log "📁 Створення директорій для встановлення..."
    sudo mkdir -p /opt/cni/bin
    sudo mkdir -p /etc/cni/net.d
    
    log "📋 Копіювання бінарного файлу..."
    sudo cp simple-cni /opt/cni/bin/
    sudo chmod +x /opt/cni/bin/simple-cni
    
    log "📄 Створення конфігурації CNI..."
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
    
    sudo cp /tmp/10-simple-cni.conf /etc/cni/net.d/
    
    log "✅ CNI встановлено локально!"
    log "📋 Перевірка встановлення:"
    ls -la /opt/cni/bin/simple-cni
    ls -la /etc/cni/net.d/10-simple-cni.conf
    
    echo ""
    log "🎉 Встановлення завершено!"
    log "Для використання в Kubernetes:"
    echo "  1. Скопіюйте бінарний файл на всі вузли кластера"
    echo "  2. Налаштуйте kubelet для використання simple-cni"
    echo "  3. Або використовуйте Helm chart для розгортання"
    
else
    error "❌ Помилка збірки"
    exit 1
fi 