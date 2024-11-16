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

# Функция для получения учетных данных
get_credentials() {
if gpg --quiet --decrypt --batch --yes "$CREDENTIALS_FILE" 2>/dev/null; then
readarray -t credentials < <(gpg --quiet --decrypt "$CREDENTIALS_FILE")
username="${credentials[0]}"
password="${credentials[1]}"
echo "Используем сохраненные учетные данные."
else
read -p "Введите логин: " username
read -sp "Введите пароль: " password
echo
echo -e "$username\n$password" | gpg --symmetric --cipher-algo AES256 -o "$CREDENTIALS_FILE"
echo "Учетные данные сохранены."
fi
}

# Функция для подключения к VPN
connect_vpn() {
local config_file="$1"
echo "Подключение к VPN с конфигурацией: $config_file"

get_credentials

# Подключаемся к VPN
while true; do
echo -e "$username\n$password" | sudo openvpn --config "$config_file" --auth-user-pass /dev/stdin

if [[ $? -eq 0 ]]; then
echo "Подключение успешно!"
break
else
echo "Ошибка подключения. Пожалуйста, попробуйте снова."
fi
done
}

# Функция для выбора конфигурации
select_config() {
    local dir="$1"
    echo "Доступные конфигурации в $(basename "$dir"):"  # Отображаем только имя папки
    configs=()
    while IFS= read -r -d '' config; do
        configs+=("$(basename "$config")")  # Получаем только имя конфигурационного файла
    done < <(find "$dir" -maxdepth 1 -name "*.ovpn" -print0)

    select config in "${configs[@]}"; do
        if [[ -n "$config" ]]; then
            # Получаем полный путь к выбранному конфигурационному файлу
            selected_config="$dir/$config"
            connect_vpn "$selected_config"
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
    folders+=("$(basename "$folder")")  # Получаем только имя папки
done < <(find "$BASE_VPN_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

select folder in "${folders[@]}"; do
    if [[ -n "$folder" ]]; then
        # Получаем полный путь к выбранной папке
        selected_folder="$BASE_VPN_DIR$folder"
        select_config "$selected_folder"
        break
    else
        echo "Неверный выбор. Пожалуйста, выберите номер из списка."
    fi
done