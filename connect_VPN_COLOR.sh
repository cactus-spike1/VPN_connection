#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Без цвета

# Основная директория с папками конфигураций OpenVPN
BASE_VPN_DIR="/mnt/cactus_spike1/VPN/"
CREDENTIALS_FILE="$HOME/.vpn_credentials.gpg"

# Проверка наличия OpenVPN
if ! command -v openvpn &> /dev/null; then
    echo -e "${RED}OpenVPN не установлен. Пожалуйста, установите его и попробуйте снова.${NC}"
    exit 1
fi

# Функция для получения учетных данных
get_credentials() {
    if gpg --quiet --decrypt --batch --yes "$CREDENTIALS_FILE" 2>/dev/null; then
        readarray -t credentials < <(gpg --quiet --decrypt "$CREDENTIALS_FILE")
        username="${credentials[0]}"
        password="${credentials[1]}"
        echo -e "${GREEN}Используем сохраненные учетные данные.${NC}"
    else
        read -p "Введите логин: " username
        read -sp "Введите пароль: " password
        echo
        echo -e "$username\n$password" | gpg --symmetric --cipher-algo AES256 -o "$CREDENTIALS_FILE"
        echo -e "${GREEN}Учетные данные сохранены.${NC}"
    fi
}

# Функция для подключения к VPN
connect_vpn() {
    local config_file="$1"
    echo -e "${BLUE}Подключение к VPN с конфигурацией: $config_file${NC}"

    get_credentials

    while true; do
        echo -e "$username\n$password" | sudo openvpn --config "$config_file" --auth-user-pass /dev/stdin

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Подключение успешно!${NC}"
            break
        else
            echo -e "${RED}Ошибка подключения. Пожалуйста, попробуйте снова.${NC}"
        fi
    done
}

# Функция для выбора конфигурации
select_config() {
    local dir="$1"
    echo -e "${YELLOW}=== Доступные конфигурации в $(basename "$dir") ===${NC}"
    configs=()
    while IFS= read -r -d '' config; do
        configs+=("$(basename "$config")")
    done < <(find "$dir" -maxdepth 1 -name "*.ovpn" -print0)

    select config in "${configs[@]}"; do
        if [[ -n "$config" ]]; then
            selected_config="$dir/$config"
            connect_vpn "$selected_config"
            break
        else
            echo -e "${RED}Неверный выбор. Пожалуйста, выберите номер из списка.${NC}"
        fi
    done
}

# Основной цикл для выбора папки
echo -e "${YELLOW}=== Доступные папки с конфигурациями ===${NC}"
echo "-----------------------------------------"
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
                echo -e "${RED}Неверный выбор. Пожалуйста, выберите номер из списка.${NC}"
    fi
done