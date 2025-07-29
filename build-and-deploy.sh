#!/bin/bash

set -e

echo "🚀 Збірка та розгортання Simple CNI"

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функція для логування
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Перевіряємо чи встановлений Docker
if ! command -v docker &> /dev/null; then
    warn "Docker не встановлений. Використовуємо локальну збірку."
    log "🔨 Локальна збірка..."
    chmod +x build-local.sh
    ./build-local.sh
    exit 0
fi

# Перевіряємо чи запущений Docker daemon
if ! docker info &> /dev/null; then
    warn "Docker daemon не запущений. Використовуємо локальну збірку."
    log "🔨 Локальна збірка..."
    chmod +x build-local.sh
    ./build-local.sh
    exit 0
fi

# Перевіряємо чи встановлений kubectl
if ! command -v kubectl &> /dev/null; then
    error "kubectl не встановлений. Будь ласка, встановіть kubectl."
    exit 1
fi

# Перевіряємо чи встановлений Helm
if ! command -v helm &> /dev/null; then
    warn "Helm не встановлений. Встановлюємо Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

log "🔨 Збірка Docker образу..."
docker build -t simple-cni:latest .

if [ $? -eq 0 ]; then
    log "✅ Docker образ успішно зібрано"
else
    error "❌ Помилка збірки Docker образу"
    exit 1
fi

# Питаємо користувача про спосіб розгортання
echo ""
echo "Виберіть спосіб розгортання:"
echo "1) Використовувати Helm chart (рекомендовано)"
echo "2) Використовувати прямі YAML файли"
echo "3) Тільки збірка (без розгортання)"
read -p "Введіть номер (1-3): " choice

case $choice in
    1)
        log "📦 Розгортання через Helm..."
        
        # Створюємо namespace якщо не існує
        kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -
        
        # Розгортаємо через Helm
        helm install simple-cni ./helm \
            --namespace kube-system \
            --set image.repository=simple-cni \
            --set image.tag=latest \
            --set image.pullPolicy=IfNotPresent
        
        log "✅ CNI розгорнуто через Helm"
        log "Перевірте статус: kubectl get pods -n kube-system -l app.kubernetes.io/name=simple-cni"
        ;;
    2)
        log "📄 Розгортання через YAML файли..."
        
        # Створюємо namespace якщо не існує
        kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f -
        
        # Застосовуємо YAML файли
        kubectl apply -f k8s/rbac.yaml
        kubectl apply -f k8s/cni-config.yaml
        kubectl apply -f k8s/daemonset-init.yaml
        
        log "✅ CNI розгорнуто через YAML файли"
        log "Перевірте статус: kubectl get pods -n kube-system -l app=simple-cni"
        
        # Налаштовуємо kubelet
        log "🔧 Налаштування kubelet..."
        chmod +x setup-kubelet.sh
        ./setup-kubelet.sh
        ;;
    3)
        log "✅ Збірка завершена. Образ готовий для розгортання."
        log "Для ручного розгортання використовуйте:"
        echo "  kubectl apply -f k8s/"
        echo "  або"
        echo "  helm install simple-cni ./helm"
        ;;
    *)
        error "Невірний вибір"
        exit 1
        ;;
esac

echo ""
log "📋 Корисні команди для перевірки:"
echo "  kubectl get pods -n kube-system -l app=simple-cni"
echo "  kubectl logs -n kube-system -l app=simple-cni"
echo "  kubectl describe daemonset simple-cni -n kube-system"
echo ""
log "🔧 Для налаштування CNI як основного мережевого плагіна:"
echo "  kubectl get nodes -o yaml | grep -A 5 kubelet"
echo "  # Відредагуйте конфігурацію kubelet для використання simple-cni" 