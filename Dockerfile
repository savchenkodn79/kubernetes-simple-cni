# Многоетапна збірка для CNI
FROM golang:1.21-alpine AS builder

# Встановлюємо необхідні пакети для збірки
RUN apk add --no-cache git gcc musl-dev

# Встановлюємо робочу директорію
WORKDIR /app

# Копіюємо файли залежностей
COPY go.mod ./

# Завантажуємо залежності та створюємо go.sum
RUN go mod download && go mod tidy

# Копіюємо код
COPY . .

# Збираємо CNI бінарний файл
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o simple-cni .

# Фінальний образ
FROM alpine:latest

# Встановлюємо необхідні мережеві інструменти
RUN apk add --no-cache \
    iproute2 \
    iptables \
    bridge-utils \
    && rm -rf /var/cache/apk/*

# Копіюємо бінарний файл
COPY --from=builder /app/simple-cni /opt/cni/bin/simple-cni

# Робимо файл виконуваним
RUN chmod +x /opt/cni/bin/simple-cni

# Встановлюємо робочу директорію
WORKDIR /opt/cni/bin

# Команда за замовчуванням
CMD ["./simple-cni"] 