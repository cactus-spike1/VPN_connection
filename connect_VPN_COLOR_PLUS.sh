#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # Без цвета

# Основная директория с папками конфигураций OpenVPN
BASE_VPN_DIR="/mnt/cactus_spike1/VPN/"
CREDENTIALS_FILE="$HOME/.vpn_credentials.gpg"

# Функция для создания заголовка с анимацией
print_animated_header() {
    text="$1"
    length=${#text}
    border=$(printf '═%.0s' $(seq 1 $length))

    echo -e "${CYAN}╔═${border}═╗${NC}"
    for (( i=0; i<$length; i++ )); do
        printf "${CYAN}║ ${MAGENTA}${text:i:1}${CYAN} ║\r"
        sleep 0.05
    done
    echo -e "${CYAN}║ ${MAGENTA}${text}${CYAN} ║${NC}"
    echo -e "${CYAN}╚═${border}═╝${NC}"
}

# Проверка наличия OpenVPN
if ! command -v openvpn &> /dev/null; then
    echo -e "${RED}OpenVPN не установлен. Пожалуйста, установите его и попробуйте снова.${NC}"
    exit 1
fi

# Функция для получения учетных данных
get_credentials() {
    print_animated_header "Получение учетных данных"
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
    print_animated_header "Подключение к VPN"
    echo -e "${BLUE}Подключение с использованием конфигурации: ${WHITE}$config_file${NC}"
    get_credentials

    while true; do
        echo -e "$username\n$password" | sudo openvpn --config "$config_file" --auth-user-pass /dev/stdin

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Подключение успешно!${NC}"
            break
        else
            echo -e "${RED}❌ Ошибка подключения.${NC}"
            echo -e "${YELLOW}Выберите действие:${NC}"
            echo -e "${WHITE}q${NC} - выход"
            echo -e "${WHITE}r${NC} - изменить учетные данные и повторить"

            read -p "Введите ваш выбор: " choice
            if [[ "$choice" == "q" ]]; then
                echo -e "${YELLOW}Выход...${NC}"
                break
            elif [[ "$choice" == "r" ]]; then
                echo -e "${CYAN}Изменение учетных данных...${NC}"
                read -p "Введите новый логин: " username
                read -sp "Введите новый пароль: " password
                echo
                echo -e "$username\n$password" | gpg --symmetric --cipher-alго AES256 -o "$CREDENTIALS_FILE"
                echo -e "${GREEN}Учетные данные обновлены.${NC}"
            else
                echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
            fi
        fi
    done
}

# Функция для выбора конфигурации
select_config() {
    local dir="$1"
    print_animated_header "Выбор конфигурации"
    configs=()
    while IFS= read -r -d '' config; do
        configs+=("$(basename "$config")")
    done < <(find "$dir" -maxdepth 1 -name "*.ovpn" -print0)

    if [[ ${#configs[@]} -eq 0 ]]; then
        echo -e "${RED}Конфигурации не найдены в выбранной папке.${NC}"
        return
    fi

    echo -e "${CYAN}Выберите конфигурацию:${NC}"
    for i in "${!configs[@]}"; do
        printf "${MAGENTA}[%d]${WHITE} %s${NC}\n" "$((i + 1))" "${configs[$i]}"
    done

    read -p "Введите номер конфигурации: " choice
    if [[ "$choice" -gt 0 && "$choice" -le ${#configs[@]} ]]; then
        selected_config="$dir/${configs[$((choice - 1))]}"
        connect_vpn "$selected_config"
    else
        echo -e "${RED}Неверный выбор. Пожалуйста, попробуйте снова.${NC}"
    fi
}

# Основной цикл для выбора папки
print_animated_header "Доступные папки с конфигурациями"
folders=()
while IFS= read -r -d '' folder; do
    folders+=("$(basename "$folder")")
done < <(find "$BASE_VPN_DIR" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ ${#folders[@]} -eq 0 ]]; then
    echo -e "${RED}Папки с конфигурациями не найдены.${NC}"
    exit 1
fi

echo -e "${CYAN}Выберите папку:${NC}"
for i in "${!folders[@]}"; do
    printf "${MAGENTA}[%d]${WHITE} %s${NC}\n" "$((i + 1))" "${folders[$i]}"
done

read -p "Введите номер папки: " folder_choice
if [[ "$folder_choice" -gt 0 && "$folder_choice" -le ${#folders[@]} ]]; then
    selected_folder="$BASE_VPN_DIR${folders[$((folder_choice - 1))]}"
    select_config "$selected_folder"
else
    echo -e "${RED}Неверный выбор. Пожалуйста, попробуйте снова.${NC}"
fi
