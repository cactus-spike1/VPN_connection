#!/bin/bash

# Основная директория с папками конфигураций OpenVPN
BASE_VPN_DIR="/mnt/cactus_spike1/VPN/"
# Файл для хранения логина и пароля
CREDENTIALS_FILE="$HOME/.vpn_credentials.gpg"

# Проверка наличия OpenVPN
if ! command -v openvpn &> /dev/null; then
    echo "OpenVPN не установлен. Пожалуйста, установите его и попробуйте снова."
    exit 1
fi

# Функция для подключения к VPN
connect_vpn() {
    local config_file="$1"
    echo "Подключение к VPN с конфигурацией: $config_file"

    # Проверяем, существует ли файл с учетными данными
    if gpg --quiet --decrypt --batch --yes "$CREDENTIALS_FILE" 2>/dev/null; then
        # Загружаем логин и пароль из файла
        readarray -t credentials < <(gpg --quiet --decrypt "$CREDENTIALS_FILE")
        username="${credentials[0]}"
        password="${credentials[1]}"
        echo "Используем сохраненные учетные данные."
    else
        # Запрашиваем логин и пароль
        read -p "Введите логин: " username
        read -sp "Введите пароль: " password
        echo

        # Сохраняем логин и пароль в зашифрованный файл
        echo -e "$username\n$password" | gpg --symmetric --cipher-algo AES256 -o "$CREDENTIALS_FILE"
        echo "Учетные данные сохранены."
    fi

    # Создаем временный файл для хранения логина и пароля
    auth_file=$(mktemp)
    echo "$username" > "$auth_file"
    echo "$password" >> "$auth_file"

    while true; do
        # Подключаемся к VPN
        sudo openvpn --config "$config_file" --auth-user-pass "$auth_file"
        
        # Проверяем код завершения последней команды
        if [[ $? -eq 0 ]]; then
            echo "Подключение успешно!"
            break
        else
            echo "Ошибка подключения. Пожалуйста, попробуйте снова."
            echo "Используем сохраненные учетные данные."
        fi
    done

    # Удаляем временный файл после успешного подключения или в случае ошибки
    rm -f "$auth_file"
}

# Функция для выбора конфигурации
select_config() {
    local dir="$1"
    echo "Доступные конфигурации в $dir:"
    select config in "$dir"/*.ovpn; do
        if [[ -n "$config" ]]; then
            connect_vpn "$config"
            break
        else
            echo "Неверный выбор. Пожалуйста, выберите номер из списка."
        fi
    done
}

# Основной цикл для выбора папки
echo "Доступные папки с конфигурациями:"
folders=()
while IFS= read -r -d '' folder; do
    folders+=("$folder")
done < <(find "$BASE_VPN_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

select folder in "${folders[@]}"; do
    if [[ -n "$folder" ]]; then
        select_config "$folder"
        break
    else
        echo "Неверный выбор. Пожалуйста, выберите номер из списка."
    fi
done
