#!/bin/bash

# =============================================================================
# Ubuntu Server Setup Wizard v1.0
# Интерактивный мастер настройки Ubuntu Server для VPN
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Логирование
LOGFILE="/var/log/ubuntu-setup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo -e "${1}" | tee -a "$LOGFILE"
}

log_info() {
    log "${CYAN}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Проверка прав суперпользователя
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами root"
        log_info "Используйте: sudo $0"
        exit 1
    fi
}

# Проверка совместимости системы
check_system() {
    log_info "Проверка системы..."
    
    # Проверка ОС
    if ! command -v lsb_release &> /dev/null; then
        apt-get update -qq && apt-get install -y lsb-release
    fi
    
    OS=$(lsb_release -si)
    VERSION=$(lsb_release -sr)
    
    if [[ "$OS" != "Ubuntu" ]]; then
        log_error "Поддерживается только Ubuntu Server. Обнаружена: $OS"
        exit 1
    fi
    
    # Проверка версии Ubuntu
    if [[ $(echo "$VERSION >= 20.04" | bc -l) -ne 1 ]]; then
        log_warning "Рекомендуется Ubuntu 20.04 или новее. Текущая версия: $VERSION"
        read -p "Продолжить? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Система совместима: $OS $VERSION"
}

# Создание резервной копии важных файлов
backup_configs() {
    local backup_dir="/root/config-backup-$(date +%Y%m%d-%H%M%S)"
    log_info "Создание резервной копии конфигураций в $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Список файлов для резервного копирования
    local files_to_backup=(
        "/etc/ssh/sshd_config"
        "/etc/ufw/ufw.conf"
        "/etc/sudoers"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/timezone"
        "/etc/fail2ban/jail.conf"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$backup_dir/" 2>/dev/null || true
        fi
    done
    
    log_success "Резервная копия создана: $backup_dir"
    echo "BACKUP_DIR=$backup_dir" >> /tmp/setup-vars
}

# Сбор информации от пользователя
gather_user_input() {
    log_info "=== Настройка параметров сервера ==="
    
    # Имя сервера
    read -p "Введите hostname сервера [ubuntu-server]: " SERVER_HOSTNAME
    SERVER_HOSTNAME=${SERVER_HOSTNAME:-ubuntu-server}
    
    # Временная зона
    echo "Доступные временные зоны:"
    echo "1) Europe/Moscow"
    echo "2) Europe/Kiev"
    echo "3) UTC"
    echo "4) Другая (введите вручную)"
    read -p "Выберите временную зону [1]: " tz_choice
    
    case $tz_choice in
        1|"") TIMEZONE="Europe/Moscow" ;;
        2) TIMEZONE="Europe/Kiev" ;;
        3) TIMEZONE="UTC" ;;
        4) 
            read -p "Введите временную зону (например, America/New_York): " TIMEZONE
            ;;
        *) TIMEZONE="Europe/Moscow" ;;
    esac
    
    # Настройка пользователя
    log_info "=== Настройка пользователя ==="
    read -p "Создать нового пользователя? (y/n) [y]: " create_user
    create_user=${create_user:-y}
    
    if [[ $create_user =~ ^[Yy]$ ]]; then
        read -p "Имя пользователя: " USERNAME
        while [[ -z "$USERNAME" ]]; do
            log_error "Имя пользователя не может быть пустым"
            read -p "Имя пользователя: " USERNAME
        done
        
        # Проверка, что пользователь не существует
        if id "$USERNAME" &>/dev/null; then
            log_error "Пользователь $USERNAME уже существует"
            exit 1
        fi
        
        echo "Пароль для $USERNAME будет сгенерирован автоматически"
    else
        USERNAME=""
    fi
    
    # SSH настройки
    log_info "=== Настройка SSH ==="
    read -p "SSH порт [22]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    
    # Валидация порта
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
        log_error "Неверный порт SSH. Используется порт по умолчанию: 22"
        SSH_PORT=22
    fi
    
    read -p "Отключить вход по паролю (только ключи)? (y/n) [y]: " disable_password_auth
    DISABLE_PASSWORD_AUTH=${disable_password_auth:-y}
    
    read -p "Отключить root доступ через SSH? (y/n) [y]: " disable_root_ssh
    DISABLE_ROOT_SSH=${disable_root_ssh:-y}
    
    # SSH ключ
    if [[ $DISABLE_PASSWORD_AUTH =~ ^[Yy]$ ]] && [[ -n "$USERNAME" ]]; then
        log_warning "Для отключения парольной аутентификации необходим SSH ключ"
        echo "Варианты:"
        echo "1) Вставить публичный ключ сейчас"
        echo "2) Загрузить из файла"
        echo "3) Пропустить (настроить позже вручную)"
        read -p "Выберите вариант [1]: " key_choice
        
        case $key_choice in
            1|"")
                echo "Вставьте ваш публичный SSH ключ (ssh-rsa... или ssh-ed25519...):"
                read -r SSH_PUBLIC_KEY
                ;;
            2)
                read -p "Путь к файлу с публичным ключом: " key_file
                if [[ -f "$key_file" ]]; then
                    SSH_PUBLIC_KEY=$(cat "$key_file")
                else
                    log_error "Файл не найден: $key_file"
                    SSH_PUBLIC_KEY=""
                fi
                ;;
            3)
                SSH_PUBLIC_KEY=""
                log_warning "SSH ключ не настроен. Настройте его вручную перед отключением парольной аутентификации!"
                ;;
        esac
        
        # Валидация SSH ключа
        if [[ -n "$SSH_PUBLIC_KEY" ]]; then
            if ! echo "$SSH_PUBLIC_KEY" | ssh-keygen -l -f - &>/dev/null; then
                log_error "Неверный формат SSH ключа"
                SSH_PUBLIC_KEY=""
            fi
        fi
    else
        SSH_PUBLIC_KEY=""
    fi
    
    # Дополнительные пакеты
    log_info "=== Дополнительные пакеты ==="
    echo "Выберите дополнительные пакеты для установки:"
    echo "1) htop, tree, mc, nano - базовые утилиты"
    echo "2) docker.io - Docker контейнеры"  
    echo "3) nginx - веб-сервер"
    echo "4) все вышеперечисленное"
    echo "5) только системные пакеты"
    read -p "Выберите [4]: " package_choice
    
    INSTALL_BASIC_TOOLS="no"
    INSTALL_DOCKER="no"
    INSTALL_NGINX="no"
    
    case $package_choice in
        1) INSTALL_BASIC_TOOLS="yes" ;;
        2) INSTALL_DOCKER="yes" ;;
        3) INSTALL_NGINX="yes" ;;
        4|"") 
            INSTALL_BASIC_TOOLS="yes"
            INSTALL_DOCKER="yes"
            INSTALL_NGINX="yes"
            ;;
        5) ;;
    esac
    
    # Сохранение переменных
    cat > /tmp/setup-vars << EOF
SERVER_HOSTNAME="$SERVER_HOSTNAME"
TIMEZONE="$TIMEZONE"
USERNAME="$USERNAME"
SSH_PORT="$SSH_PORT"
DISABLE_PASSWORD_AUTH="$DISABLE_PASSWORD_AUTH"
DISABLE_ROOT_SSH="$DISABLE_ROOT_SSH"
SSH_PUBLIC_KEY="$SSH_PUBLIC_KEY"
INSTALL_BASIC_TOOLS="$INSTALL_BASIC_TOOLS"
INSTALL_DOCKER="$INSTALL_DOCKER"
INSTALL_NGINX="$INSTALL_NGINX"
EOF
    
    # Подтверждение настроек
    log_info "=== Подтверждение настроек ==="
    echo "Hostname: $SERVER_HOSTNAME"
    echo "Временная зона: $TIMEZONE"
    echo "Новый пользователь: ${USERNAME:-'не создается'}"
    echo "SSH порт: $SSH_PORT"
    echo "Отключить парольную аутентификацию: $DISABLE_PASSWORD_AUTH"
    echo "Отключить root SSH: $DISABLE_ROOT_SSH"
    echo "SSH ключ: ${SSH_PUBLIC_KEY:+настроен}"
    echo "Дополнительные пакеты: базовые[$INSTALL_BASIC_TOOLS] docker[$INSTALL_DOCKER] nginx[$INSTALL_NGINX]"
    
    echo
    read -p "Продолжить с этими настройками? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Настройка отменена"
        exit 0
    fi
}

# Основная функция установки
main() {
    log_info "=== Ubuntu Server Setup Wizard v1.0 ==="
    log_info "Начало настройки: $TIMESTAMP"
    
    check_root
    check_system
    backup_configs
    gather_user_input
    
    log_info "Запуск основного скрипта установки..."
    
    # Загружаем переменные и запускаем основной скрипт
    source /tmp/setup-vars
    
    # Здесь будет вызов основного скрипта установки
    if [[ -f "./main-setup.sh" ]]; then
        bash ./main-setup.sh
    else
        log_error "Файл main-setup.sh не найден"
        log_info "Скачиваем основной скрипт..."
        # В реальности здесь будет curl/wget для скачивания
        log_error "Функция скачивания не реализована. Поместите main-setup.sh в текущую директорию."
        exit 1
    fi
}

# Обработка сигналов
trap 'log_error "Настройка прервана"; exit 1' INT TERM

# Запуск
main "$@"
