#!/bin/bash

# =============================================================================
# Ubuntu Server Automation Suite - One-Click Installer  
# =============================================================================

set -euo pipefail

# ВАЖНО: Замените YOUR_GITHUB_USERNAME на ваше имя пользователя!
GITHUB_USERNAME="YOUR_GITHUB_USERNAME"
REPO_NAME="ubuntu-server-automation"
REPO_URL="https://raw.githubusercontent.com/$GITHUB_USERNAME/$REPO_NAME/main"
INSTALL_DIR="/opt/ubuntu-automation"

# Цвета для красивого вывода
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка root прав
if [[ $EUID -ne 0 ]]; then
    log_error "Запустите с правами root: sudo $0"
    exit 1
fi

echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║          🚀 Ubuntu Server Automation Suite                  ║
║                                                              ║
║     Автоматизация настройки Ubuntu Server                   ║
║     с максимальной безопасностью                            ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "Начинаем установку скриптов автоматизации..."

# Создание директорий
log_info "Создание директорий..."
mkdir -p "$INSTALL_DIR/scripts"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/backups"

# Список скриптов для загрузки
scripts=("setup-wizard.sh" "main-setup.sh" "ssh-hardening.sh" "security-firewall.sh")

# Загрузка скриптов
log_info "Загрузка скриптов из GitHub..."
for script in "${scripts[@]}"; do
    log_info "⬇️  Загружается: $script"
    
    if curl -fsSL "$REPO_URL/scripts/$script" -o "$INSTALL_DIR/scripts/$script"; then
        chmod +x "$INSTALL_DIR/scripts/$script"
        log_success "✅ $script загружен и готов к использованию"
    else
        log_error "❌ Ошибка загрузки $script"
        log_error "Проверьте подключение к интернету и правильность имени пользователя GitHub"
        exit 1
    fi
done

# Создание удобных команд
log_info "Создание команд системы..."
ln -sf "$INSTALL_DIR/scripts/setup-wizard.sh" /usr/local/bin/ubuntu-setup
ln -sf "$INSTALL_DIR/scripts/ssh-hardening.sh" /usr/local/bin/ubuntu-ssh
ln -sf "$INSTALL_DIR/scripts/security-firewall.sh" /usr/local/bin/ubuntu-security

# Создание информационного файла
cat > "$INSTALL_DIR/info.txt" << EOF
Ubuntu Server Automation Suite
Установлено: $(date)
Источник: https://github.com/$GITHUB_USERNAME/$REPO_NAME

Доступные команды:
- ubuntu-setup    : Полная настройка сервера
- ubuntu-ssh      : Настройка SSH безопасности  
- ubuntu-security : Настройка файрвола и защиты

Логи установки: $INSTALL_DIR/logs/
Резервные копии: $INSTALL_DIR/backups/
EOF

log_success "🎉 Установка успешно завершена!"
echo
echo -e "${GREEN}Доступные команды:${NC}"
echo -e "  ${CYAN}ubuntu-setup${NC}    - Полная автоматическая настройка сервера"
echo -e "  ${CYAN}ubuntu-ssh${NC}      - Настройка SSH безопасности"  
echo -e "  ${CYAN}ubuntu-security${NC} - Настройка файрвола и защиты"
echo
echo -e "${YELLOW}Для начала настройки выполните:${NC}"
echo -e "  ${GREEN}sudo ubuntu-setup${NC}"
echo
log_info "Документация: https://github.com/$GITHUB_USERNAME/$REPO_NAME"
