#!/bin/bash

# =============================================================================
# Ubuntu Server Main Setup Script v1.0
# Основной скрипт автоматической настройки Ubuntu Server
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Глобальные переменные
LOGFILE="/var/log/ubuntu-setup.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Функции логирования
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

# Функция выполнения команд с проверкой
run_command() {
    local cmd="$1"
    local description="$2"
    
    log_info "Выполняется: $description"
    if eval "$cmd" >> "$LOGFILE" 2>&1; then
        log_success "$description - завершено"
        return 0
    else
        log_error "$description - ошибка"
        return 1
    fi
}

# Загрузка переменных конфигурации
load_config() {
    if [[ -f "/tmp/setup-vars" ]]; then
        source /tmp/setup-vars
        log_success "Конфигурация загружена"
    else
        log_error "Файл конфигурации не найден"
        exit 1
    fi
}

# Обновление системы
update_system() {
    log_info "=== ОБНОВЛЕНИЕ СИСТЕМЫ ==="
    
    run_command "apt-get update" "Обновление списка пакетов"
    run_command "apt-get upgrade -y" "Обновление установленных пакетов"
    run_command "apt-get autoremove -y" "Удаление неиспользуемых пакетов"
    run_command "apt-get autoclean" "Очистка кеша пакетов"
    
    log_success "Система обновлена"
}

# Установка необходимых пакетов
install_packages() {
    log_info "=== УСТАНОВКА ПАКЕТОВ ==="
    
    # Системные пакеты (всегда устанавливаются)
    local system_packages=(
        "curl"
        "wget"
        "gnupg2"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "lsb-release"
        "ufw"
        "fail2ban"
        "unattended-upgrades"
        "logrotate"
        "rsyslog"
        "ntp"
        "bc"
        "jq"
    )
    
    # Базовые утилиты
    local basic_tools=(
        "htop"
        "tree"
        "mc"
        "nano"
        "vim"
        "git"
        "zip"
        "unzip"
        "screen"
        "tmux"
    )
    
    # Установка системных пакетов
    local packages_to_install=("${system_packages[@]}")
    
    # Добавление дополнительных пакетов по выбору
    if [[ "$INSTALL_BASIC_TOOLS" == "yes" ]]; then
        packages_to_install+=("${basic_tools[@]}")
        log_info "Добавлены базовые утилиты"
    fi
    
    # Установка всех пакетов одной командой
    local package_list="${packages_to_install[*]}"
    run_command "apt-get install -y $package_list" "Установка пакетов: $package_list"
    
    # Docker установка отдельно
    if [[ "$INSTALL_DOCKER" == "yes" ]]; then
        install_docker
    fi
    
    # Nginx установка отдельно
    if [[ "$INSTALL_NGINX" == "yes" ]]; then
        run_command "apt-get install -y nginx" "Установка Nginx"
        run_command "systemctl enable nginx" "Включение автозапуска Nginx"
    fi
    
    log_success "Пакеты установлены"
}

# Установка Docker
install_docker() {
    log_info "Установка Docker..."
    
    # Удаление старых версий
    run_command "apt-get remove -y docker docker-engine docker.io containerd runc" "Удаление старых версий Docker" || true
    
    # Добавление официального GPG ключа Docker
    run_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" "Добавление GPG ключа Docker"
    
    # Добавление репозитория
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    run_command "apt-get update" "Обновление списка пакетов"
    run_command "apt-get install -y docker-ce docker-ce-cli containerd.io" "Установка Docker"
    run_command "systemctl enable docker" "Включение автозапуска Docker"
    run_command "systemctl start docker" "Запуск Docker"
    
    # Добавление пользователя в группу docker
    if [[ -n "$USERNAME" ]]; then
        run_command "usermod -aG docker $USERNAME" "Добавление пользователя $USERNAME в группу docker"
    fi
    
    log_success "Docker установлен"
}

# Настройка hostname и timezone
configure_system() {
    log_info "=== НАСТРОЙКА СИСТЕМЫ ==="
    
    # Настройка hostname
    run_command "hostnamectl set-hostname $SERVER_HOSTNAME" "Установка hostname: $SERVER_HOSTNAME"
    
    # Обновление /etc/hosts
    if ! grep -q "127.0.1.1.*$SERVER_HOSTNAME" /etc/hosts; then
        echo "127.0.1.1 $SERVER_HOSTNAME" >> /etc/hosts
        log_success "Обновлен файл /etc/hosts"
    fi
    
    # Настройка временной зоны
    run_command "timedatectl set-timezone $TIMEZONE" "Установка временной зоны: $TIMEZONE"
    
    # Синхронизация времени
    run_command "systemctl enable ntp" "Включение синхронизации времени"
    run_command "systemctl start ntp" "Запуск службы времени"
    
    log_success "Система настроена"
}

# Создание пользователя
create_user() {
    if [[ -z "$USERNAME" ]]; then
        log_info "Создание пользователя пропущено"
        return 0
    fi
    
    log_info "=== СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ ==="
    
    # Генерация случайного пароля
    local password=$(openssl rand -base64 32)
    
    # Создание пользователя
    run_command "useradd -m -s /bin/bash $USERNAME" "Создание пользователя $USERNAME"
    
    # Установка пароля
    echo "$USERNAME:$password" | chpasswd
    
    # Добавление в группы
    run_command "usermod -aG sudo $USERNAME" "Добавление $USERNAME в группу sudo"
    run_command "usermod -aG adm $USERNAME" "Добавление $USERNAME в группу adm"
    
    # Сохранение пароля в безопасное место
    echo "Пользователь: $USERNAME" > "/root/${USERNAME}_credentials.txt"
    echo "Пароль: $password" >> "/root/${USERNAME}_credentials.txt"
    chmod 600 "/root/${USERNAME}_credentials.txt"
    
    log_success "Пользователь $USERNAME создан. Пароль сохранен в /root/${USERNAME}_credentials.txt"
    
    # Настройка SSH ключей
    if [[ -n "$SSH_PUBLIC_KEY" ]]; then
        setup_ssh_keys
    fi
}

# Настройка SSH ключей
setup_ssh_keys() {
    log_info "Настройка SSH ключей для пользователя $USERNAME"
    
    local user_home="/home/$USERNAME"
    local ssh_dir="$user_home/.ssh"
    
    # Создание директории .ssh
    run_command "mkdir -p $ssh_dir" "Создание директории $ssh_dir"
    run_command "chown $USERNAME:$USERNAME $ssh_dir" "Установка владельца $ssh_dir"
    run_command "chmod 700 $ssh_dir" "Установка прав доступа $ssh_dir"
    
    # Добавление публичного ключа
    echo "$SSH_PUBLIC_KEY" > "$ssh_dir/authorized_keys"
    run_command "chown $USERNAME:$USERNAME $ssh_dir/authorized_keys" "Установка владельца authorized_keys"
    run_command "chmod 600 $ssh_dir/authorized_keys" "Установка прав доступа authorized_keys"
    
    log_success "SSH ключи настроены"
}

# Настройка SSH сервера
configure_ssh() {
    log_info "=== НАСТРОЙКА SSH ==="
    
    local ssh_config="/etc/ssh/sshd_config"
    
    # Создание резервной копии
    cp "$ssh_config" "${ssh_config}.backup"
    
    # Настройка порта
    sed -i "s/^#Port 22/Port $SSH_PORT/" "$ssh_config"
    sed -i "s/^Port .*/Port $SSH_PORT/" "$ssh_config"
    
    # Отключение root доступа
    if [[ "$DISABLE_ROOT_SSH" == "y" ]]; then
        sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" "$ssh_config"
        sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" "$ssh_config"
        log_success "Root доступ через SSH отключен"
    fi
    
    # Отключение парольной аутентификации
    if [[ "$DISABLE_PASSWORD_AUTH" == "y" ]] && [[ -n "$SSH_PUBLIC_KEY" ]]; then
        sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" "$ssh_config"
        sed -i "s/^PasswordAuthentication .*/PasswordAuthentication no/" "$ssh_config"
        sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$ssh_config"
        sed -i "s/^PubkeyAuthentication .*/PubkeyAuthentication yes/" "$ssh_config"
        log_success "Парольная аутентификация отключена"
    else
        log_warning "Парольная аутентификация оставлена включенной"
    fi
    
    # Дополнительные настройки безопасности
    cat >> "$ssh_config" << EOF

# Additional security settings
Protocol 2
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxStartups 2
LoginGraceTime 60
EOF
    
    # Проверка конфигурации SSH
    if sshd -t; then
        run_command "systemctl reload ssh" "Перезагрузка SSH сервиса"
        log_success "SSH настроен на порту $SSH_PORT"
    else
        log_error "Ошибка в конфигурации SSH. Восстанавливаем резервную копию"
        cp "${ssh_config}.backup" "$ssh_config"
        exit 1
    fi
}

# Настройка файрвола UFW
configure_firewall() {
    log_info "=== НАСТРОЙКА ФАЙРВОЛА ==="
    
    # Сброс правил UFW
    run_command "ufw --force reset" "Сброс правил UFW"
    
    # Базовые правила
    run_command "ufw default deny incoming" "Запрет входящих соединений по умолчанию"
    run_command "ufw default allow outgoing" "Разрешение исходящих соединений по умолчанию"
    
    # Разрешение SSH
    run_command "ufw allow $SSH_PORT/tcp" "Разрешение SSH на порту $SSH_PORT"
    
    # Дополнительные порты в зависимости от установленных сервисов
    if [[ "$INSTALL_NGINX" == "yes" ]]; then
        run_command "ufw allow 'Nginx Full'" "Разрешение HTTP/HTTPS для Nginx"
    fi
    
    # Включение UFW
    run_command "ufw --force enable" "Включение UFW"
    
    log_success "Файрвол настроен"
}

# Настройка Fail2Ban
configure_fail2ban() {
    log_info "=== НАСТРОЙКА FAIL2BAN ==="
    
    # Создание локальной конфигурации
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF
    
    # Перезапуск Fail2Ban
    run_command "systemctl enable fail2ban" "Включение автозапуска Fail2Ban"
    run_command "systemctl restart fail2ban" "Перезапуск Fail2Ban"
    
    log_success "Fail2Ban настроен"
}

# Настройка автообновлений
configure_auto_updates() {
    log_info "=== НАСТРОЙКА АВТООБНОВЛЕНИЙ ==="
    
    # Настройка unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    
    # Включение автообновлений
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    run_command "systemctl enable unattended-upgrades" "Включение автообновлений"
    
    log_success "Автообновления настроены"
}

# Дополнительные настройки безопасности
security_hardening() {
    log_info "=== ДОПОЛНИТЕЛЬНАЯ БЕЗОПАСНОСТЬ ==="
    
    # Настройка sysctl для безопасности
    cat > /etc/sysctl.d/99-security.conf << EOF
# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ping requests
net.ipv4.icmp_echo_ignore_all = 0

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
EOF
    
    # Применение настроек sysctl
    run_command "sysctl -p /etc/sysctl.d/99-security.conf" "Применение настроек безопасности sysctl"
    
    # Настройка limits.conf
    cat >> /etc/security/limits.conf << EOF

# Security limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
    
    # Отключение неиспользуемых сервисов
    local services_to_disable=(
        "avahi-daemon"
        "cups"
        "bluetooth"
        "ModemManager"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            run_command "systemctl disable $service" "Отключение службы $service" || true
            run_command "systemctl stop $service" "Остановка службы $service" || true
        fi
    done
    
    log_success "Дополнительная безопасность настроена"
}

# Настройка логирования
configure_logging() {
    log_info "=== НАСТРОЙКА ЛОГИРОВАНИЯ ==="
    
    # Настройка rsyslog для централизованного логирования
    cat > /etc/rsyslog.d/50-security.conf << EOF
# Security logging
auth,authpriv.*                 /var/log/auth.log
*.*;auth,authpriv.none          -/var/log/syslog
daemon.*                        -/var/log/daemon.log
kern.*                          -/var/log/kern.log
mail.*                          -/var/log/mail.log
user.*                          -/var/log/user.log

# Emergency messages to all users
*.emerg                         :omusrmsg:*
EOF
    
    # Настройка logrotate
    cat > /etc/logrotate.d/security << EOF
/var/log/auth.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog
    endscript
}

/var/log/fail2ban.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 640 root adm
}
EOF
    
    run_command "systemctl restart rsyslog" "Перезапуск rsyslog"
    
    log_success "Логирование настроено"
}

# Финальная проверка системы
final_system_check() {
    log_info "=== ФИНАЛЬНАЯ ПРОВЕРКА СИСТЕМЫ ==="
    
    local checks_passed=0
    local total_checks=0
    
    # Функция для проверки
    check_service() {
        local service=$1
        local description=$2
        ((total_checks++))
        
        if systemctl is-active "$service" &>/dev/null; then
            log_success "$description: активен"
            ((checks_passed++))
        else
            log_warning "$description: неактивен"
        fi
    }
    
    check_service "ssh" "SSH сервис"
    check_service "ufw" "Файрвол UFW"
    check_service "fail2ban" "Fail2Ban"
    check_service "rsyslog" "Система логирования"
    
    if [[ "$INSTALL_DOCKER" == "yes" ]]; then
        check_service "docker" "Docker"
    fi
    
    if [[ "$INSTALL_NGINX" == "yes" ]]; then
        check_service "nginx" "Nginx"
    fi
    
    # Проверка сетевых настроек
    ((total_checks++))
    if ss -tlnp | grep ":$SSH_PORT" &>/dev/null; then
        log_success "SSH слушает порт $SSH_PORT"
        ((checks_passed++))
    else
        log_error "SSH не слушает порт $SSH_PORT"
    fi
    
    # Проверка UFW правил
    ((total_checks++))
    if ufw status | grep -q "$SSH_PORT/tcp.*ALLOW"; then
        log_success "UFW разрешает SSH на порту $SSH_PORT"
        ((checks_passed++))
    else
        log_warning "UFW не разрешает SSH на порту $SSH_PORT"
    fi
    
    # Проверка пользователя
    if [[ -n "$USERNAME" ]]; then
        ((total_checks++))
        if id "$USERNAME" &>/dev/null; then
            log_success "Пользователь $USERNAME создан"
            ((checks_passed++))
            
            # Проверка sudo прав
            ((total_checks++))
            if groups "$USERNAME" | grep -q sudo; then
                log_success "Пользователь $USERNAME имеет sudo права"
                ((checks_passed++))
            else
                log_warning "Пользователь $USERNAME не имеет sudo прав"
            fi
            
            # Проверка SSH ключей
            if [[ -n "$SSH_PUBLIC_KEY" ]]; then
                ((total_checks++))
                if [[ -f "/home/$USERNAME/.ssh/authorized_keys" ]]; then
                    log_success "SSH ключи настроены для $USERNAME"
                    ((checks_passed++))
                else
                    log_warning "SSH ключи не найдены для $USERNAME"
                fi
            fi
        else
            log_error "Пользователь $USERNAME не найден"
        fi
    fi
    
    # Итоговая статистика
    log_info "Проверок пройдено: $checks_passed из $total_checks"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        log_success "Все проверки пройдены успешно!"
        return 0
    else
        log_warning "Некоторые проверки не пройдены. Проверьте логи."
        return 1
    fi
}

# Создание отчета о настройке
generate_report() {
    log_info "=== СОЗДАНИЕ ОТЧЕТА ==="
    
    local report_file="/root/setup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
=============================================================================
ОТЧЕТ О НАСТРОЙКЕ UBUNTU SERVER
=============================================================================
Дата: $(date '+%Y-%m-%d %H:%M:%S')
Hostname: $SERVER_HOSTNAME
Пользователь: $(whoami)

НАСТРОЙКИ СИСТЕМЫ:
- Hostname: $SERVER_HOSTNAME
- Временная зона: $TIMEZONE
- Версия Ubuntu: $(lsb_release -d | cut -f2)
- Ядро: $(uname -r)

НАСТРОЙКИ ПОЛЬЗОВАТЕЛЯ:
- Новый пользователь: ${USERNAME:-'не создан'}
$(if [[ -n "$USERNAME" ]]; then
    echo "- Группы пользователя: $(groups $USERNAME 2>/dev/null || echo 'ошибка')"
    echo "- SSH ключи: $(if [[ -f "/home/$USERNAME/.ssh/authorized_keys" ]]; then echo 'настроены'; else echo 'не настроены'; fi)"
    echo "- Файл с паролем: /root/${USERNAME}_credentials.txt"
fi)

НАСТРОЙКИ SSH:
- Порт SSH: $SSH_PORT
- Root доступ: $(if [[ "$DISABLE_ROOT_SSH" == "y" ]]; then echo 'отключен'; else echo 'включен'; fi)
- Парольная аутентификация: $(if [[ "$DISABLE_PASSWORD_AUTH" == "y" ]]; then echo 'отключена'; else echo 'включена'; fi)

УСТАНОВЛЕННЫЕ СЕРВИСЫ:
- UFW (файрвол): $(systemctl is-active ufw)
- Fail2Ban: $(systemctl is-active fail2ban)
- SSH: $(systemctl is-active ssh)
$(if [[ "$INSTALL_DOCKER" == "yes" ]]; then echo "- Docker: $(systemctl is-active docker)"; fi)
$(if [[ "$INSTALL_NGINX" == "yes" ]]; then echo "- Nginx: $(systemctl is-active nginx)"; fi)

ОТКРЫТЫЕ ПОРТЫ:
$(ss -tlnp | grep LISTEN)

ПРАВИЛА UFW:
$(ufw status numbered)

АКТИВНЫЕ FAIL2BAN JAIL:
$(fail2ban-client status 2>/dev/null || echo "Не удалось получить статус")

СИСТЕМНАЯ ИНФОРМАЦИЯ:
- Использование диска: $(df -h / | tail -1)
- Использование памяти: $(free -h | grep Mem)
- Загрузка системы: $(uptime)

РЕЗЕРВНЫЕ КОПИИ:
- Конфигурации: $BACKUP_DIR
- Логи установки: $LOGFILE

ВАЖНО:
$(if [[ -n "$USERNAME" && -f "/root/${USERNAME}_credentials.txt" ]]; then
    echo "1. Пароль пользователя $USERNAME сохранен в /root/${USERNAME}_credentials.txt"
fi)
2. При следующем подключении используйте порт $SSH_PORT
3. $(if [[ "$DISABLE_PASSWORD_AUTH" == "y" ]]; then echo "Парольная аутентификация отключена - используйте SSH ключи"; else echo "Рекомендуется настроить SSH ключи и отключить парольную аутентификацию"; fi)
4. Проверьте доступность сервера перед закрытием текущей сессии

КОМАНДЫ ДЛЯ ПРОВЕРКИ:
- Подключение SSH: ssh $(if [[ -n "$USERNAME" ]]; then echo "$USERNAME"; else echo "root"; fi)@$(hostname -I | awk '{print $1}') -p $SSH_PORT
- Статус UFW: sudo ufw status
- Статус Fail2Ban: sudo fail2ban-client status
- Логи SSH: sudo tail -f /var/log/auth.log

=============================================================================
EOF
    
    chmod 600 "$report_file"
    log_success "Отчет создан: $report_file"
    
    # Показать краткую сводку
    log_info "=== КРАТКАЯ СВОДКА ==="
    echo "✅ Сервер настроен: $SERVER_HOSTNAME"
    echo "🔒 SSH порт: $SSH_PORT"
    if [[ -n "$USERNAME" ]]; then
        echo "👤 Пользователь: $USERNAME"
        echo "🔑 Пароль сохранен в: /root/${USERNAME}_credentials.txt"
    fi
    echo "🛡️  Файрвол: активен"
    echo "🚫 Fail2Ban: активен"
    echo "📄 Полный отчет: $report_file"
}

# Главная функция
main() {
    log_info "=== ЗАПУСК ОСНОВНОГО СКРИПТА НАСТРОЙКИ ==="
    
    # Проверка прав
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
    
    # Загрузка конфигурации
    load_config
    
    # Выполнение всех этапов настройки
    update_system
    install_packages
    configure_system
    create_user
    configure_ssh
    configure_firewall
    configure_fail2ban
    configure_auto_updates
    security_hardening
    configure_logging
    
    # Финальная проверка
    if final_system_check; then
        generate_report
        log_success "=== НАСТРОЙКА ЗАВЕРШЕНА УСПЕШНО ==="
        
        # Важное предупреждение
        echo
        log_warning "ВНИМАНИЕ! Обязательно проверьте SSH подключение в новом терминале:"
        if [[ -n "$USERNAME" ]]; then
            echo "ssh $USERNAME@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
        else
            echo "ssh root@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
        fi
        echo
        log_warning "НЕ ЗАКРЫВАЙТЕ текущую сессию до проверки!"
        
    else
        log_error "=== НАСТРОЙКА ЗАВЕРШЕНА С ОШИБКАМИ ==="
        log_info "Проверьте логи: $LOGFILE"
        exit 1
    fi
}

# Обработка сигналов
trap 'log_error "Настройка прервана"; exit 1' INT TERM

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
