#!/bin/bash

#Скрипт добавляет нового пира, создаёт ему клиентский файл,
#дописывает пира в конфиг сервера и обновляет конфигурацию интерфейса

# Переменные конфигурации
WG_INTERFACE="wg0"
SERVER_CONFIG="/etc/wireguard/$WG_INTERFACE.conf"
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/publickey)
DNS="8.8.8.8"
ENDPOINT="0.0.0.00:51820"
NETWORK="10.0.0.0/24"

# Проверка прав
if [ "$EUID" -ne 0 ]; then
        echo "Нужно запустить через sudo"
        exit 1
fi

# Запрос номера пира
read -p "Введите номер нового пира: " PEER_NUM
if [ -z "$PEER_NUM" ]; then
        echo "Номер не может быть пустым"
        exit 1
fi

# Назначение IP по порядку
LAST_IP=$(grep AllowedIPs $SERVER_CONFIG | awk {'print $3'} | cut -d'/' -f1 | sort -t . -k 4n | tail -n1)
if [ -z "$LAST_IP" ]; then
        NEW_PEER_IP="10.0.0.2/32"
else
        OCTET=${LAST_IP##*.}
        NEXT_OCTET=$(($OCTET + 1))
        NEW_PEER_IP="${LAST_IP%.*}.$NEXT_OCTET/32"
fi

# Генерация ключей
PEER_PRIVATE_KEY=$(wg genkey)
PEER_PUBLIC_KEY=$(echo "$PEER_PRIVATE_KEY" | wg pubkey)

# Создание конфига для нового пира
PEER_CONFIG="peer_$PEER_NUM.conf"
cat > "$PEER_CONFIG" << EOF
[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = $NEW_PEER_IP
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
EOF

# Добавление пира в серверный конфиг
cat >> "$SERVER_CONFIG" << EOF

[Peer]
#peer_$PEER_NUM
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = $NEW_PEER_IP
EOF

# Применение конфигурации
wg addconf $WG_INTERFACE <(wg-quick strip $WG_INTERFACE)

# Финальный вывод
echo "
Пир $PEER_NUM успешно добавлен
IP адрес нового пира: $NEW_PEER_IP
Конфигурационный файл: $PEER_CONFIG
"
