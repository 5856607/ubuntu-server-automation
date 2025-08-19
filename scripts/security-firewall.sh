#!/bin/bash

# =============================================================================
# Security & Firewall Setup Script v1.0
# Комплексная настройка безопасности и файрвола для Ubuntu Server
# =============================================================================

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Функции логирования
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
}

# Установка необходимых пакетов безопасности
install_security_packages() {
    log_info "=== УСТАНОВКА ПАКЕТОВ БЕЗОПАСНОСТИ ==="
    
    local packages=(
        "ufw"                    # Uncomplicated Firewall
        "fail2ban"              # Защита от брутфорс атак
        "iptables-persistent"   # Сохранение правил iptables
        "rkhunter"              # Rootkit hunter
        "chkrootkit"            # Проверка на rootkit
        "clamav"                # Антивирус
        "clamav-daemon"         # Демон ClamAV
        "aide"                  # Advanced Intrusion Detection Environment
        "auditd"                # Система аудита
        "psad"                  # Port Scan Attack Detector
        "logwatch"              # Анализатор логов
        "unattended-upgrades"   # Автообновления безопасности
        "needrestart"           # Уведомления о перезапуске сервисов
        "debsums"               # Проверка целостности пакетов
    )
    
    apt-get update
    
    for package in "${packages[@]}"; do
        if apt-get install -y "$package"; then
            log_success "Установлен: $package"
        else
            log_warning "Не удалось установить: $package"
        fi
    done
    
    log_success "Пакеты безопасности установлены"
}

# Настройка UFW (Uncomplicated Firewall)
configure_ufw() {
    log_info "=== НАСТРОЙКА UFW ФАЙРВОЛА ==="
    
    local ssh_port="${1:-22}"
    local allowed_services="${2:-}"
    
    # Сброс UFW к начальному состоянию
    ufw --force reset
    
    # Настройка политик по умолчанию
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny forward
    
    # Разрешение loopback интерфейса
    ufw allow in on lo
    ufw allow out on lo
    
    # Основные разрешения
    ufw allow "$ssh_port/tcp" comment "SSH"
    
    # Дополнительные сервисы
    if [[ -n "$allowed_services" ]]; then
        IFS=',' read -ra services <<< "$allowed_services"
        for service in "${services[@]}"; do
            case "$service" in
                "http"|"80")
                    ufw allow 80/tcp comment "HTTP"
                    ;;
                "https"|"443")
                    ufw allow 443/tcp comment "HTTPS"
                    ;;
                "dns"|"53")
                    ufw allow 53/udp comment "DNS"
                    ;;
                "ntp"|"123")
                    ufw allow 123/udp comment "NTP"
                    ;;
                "smtp"|"25")
                    ufw allow 25/tcp comment "SMTP"
                    ;;
                "pop3"|"110")
                    ufw allow 110/tcp comment "POP3"
                    ;;
                "imap"|"143")
                    ufw allow 143/tcp comment "IMAP"
                    ;;
                "mysql"|"3306")
                    ufw allow 3306/tcp comment "MySQL"
                    ;;
                "postgres"|"5432")
                    ufw allow 5432/tcp comment "PostgreSQL"
                    ;;
                *)
                    if [[ "$service" =~ ^[0-9]+$ ]]; then
                        ufw allow "$service/tcp" comment "Custom port $service"
                    fi
                    ;;
            esac
        done
    fi
    
    # Защита от сканирования портов
    ufw deny 23/tcp comment "Deny Telnet"
    ufw deny 135/tcp comment "Deny RPC"
    ufw deny 139/tcp comment "Deny NetBIOS"
    ufw deny 445/tcp comment "Deny SMB"
    
    # Включение UFW
    ufw --force enable
    
    # Настройка логирования
    ufw logging medium
    
    log_success "UFW настроен и активирован"
}

# Расширенная настройка iptables
configure_advanced_iptables() {
    log_info "=== РАСШИРЕННАЯ НАСТРОЙКА IPTABLES ==="
    
    # Создание пользовательских цепочек
    iptables -N SECURITY_CHAIN 2>/dev/null || true
    iptables -N DDOS_PROTECTION 2>/dev/null || true
    iptables -N PORT_SCAN_PROTECTION 2>/dev/null || true
    
    # Защита от DDoS атак
    iptables -A DDOS_PROTECTION -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
    iptables -A DDOS_PROTECTION -p tcp --dport 443 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
    iptables -A DDOS_PROTECTION -j DROP
    
    # Защита от сканирования портов
    iptables -A PORT_SCAN_PROTECTION -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT
    iptables -A PORT_SCAN_PROTECTION -p tcp --tcp-flags SYN,ACK,FIN,RST RST -j DROP
    
    # Защита от различных типов атак
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    
    # Защита от ICMP flood
    iptables -A INPUT -p icmp -m limit --limit 1/second -j ACCEPT
    iptables -A INPUT -p icmp -j DROP
    
    # Сохранение правил
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4
        log_success "Правила iptables сохранены"
    fi
    
    log_success "Расширенные правила iptables настроены"
}

# Настройка Fail2Ban
configure_fail2ban() {
    log_info "=== НАСТРОЙКА FAIL2BAN ==="
    
    local ssh_port="${1:-22}"
    
    # Создание локальной конфигурации
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Время блокировки (в секундах)
bantime = 3600

# Время окна для подсчета попыток (в секундах)
findtime = 600

# Максимальное количество попыток
maxretry = 3

# Backend для отслеживания логов
backend = systemd

# Email уведомления (настройте при необходимости)
destemail = root@localhost
sendername = Fail2Ban
mta = sendmail

# Действие при блокировке
action = %(action_mwl)s

[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600

[apache-auth]
enabled = false
port = http,https
filter = apache-auth
logpath = /var/log/apache2/*error.log
maxretry = 6

[apache-badbots]
enabled = false
port = http,https
filter = apache-badbots
logpath = /var/log/apache2/*access.log
maxretry = 2

[nginx-http-auth]
enabled = false
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 6

[nginx-limit-req]
enabled = false
port = http,https
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 10

[postfix]
enabled = false
port = smtp,465,submission
filter = postfix
logpath = /var/log/mail.log
maxretry = 3

[couriersmtp]
enabled = false
port = smtp,465,submission
filter = couriersmtp
logpath = /var/log/mail.log
maxretry = 3

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = iptables-allports[name=recidive]
bantime = 86400  # 24 часа
findtime = 86400 # 24 часа
maxretry = 5
EOF

    # Создание дополнительных фильтров
    
    # Фильтр для защиты от brute force атак на веб-сервер
    cat > /etc/fail2ban/filter.d/http-get-dos.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*" 404.*$
ignoreregex =
EOF

    # Фильтр для защиты от SQL инъекций
    cat > /etc/fail2ban/filter.d/sqli.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*(union|select|insert|delete|update|drop|create|alter|exec|script).*" 200.*$
ignoreregex =
EOF

    # Перезапуск Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban настроен и запущен"
    
    # Показать статус
    sleep 2
    if systemctl is-active --quiet fail2ban; then
        log_info "Активные jail'ы Fail2Ban:"
        fail2ban-client status | grep "Jail list" | sed 's/.*:\s*//'
    fi
}

# Настройка системы аудита
configure_auditd() {
    log_info "=== НАСТРОЙКА СИСТЕМЫ АУДИТА ==="
    
    # Базовая конфигурация auditd
    cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Удаление всех предыдущих правил
-D

# Буфер для хранения событий
-b 8192

# Поведение при отказе
-f 1

# Мониторинг системных вызовов
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Мониторинг изменений пользователей и групп
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Мониторинг сетевых настроек
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# Мониторинг MAC политик
-w /etc/selinux/ -p wa -k MAC-policy
-w /usr/share/selinux/ -p wa -k MAC-policy

# Мониторинг попыток входа
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Мониторинг процессов и сессий
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# Мониторинг изменений прав доступа
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod

# Мониторинг доступа к файлам
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# Мониторинг привилегированных команд
-a always,exit -F path=/usr/bin/passwd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-passwd
-a always,exit -F path=/usr/sbin/groupadd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-groupadd
-a always,exit -F path=/usr/sbin/groupmod -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-groupmod
-a always,exit -F path=/usr/sbin/addgroup -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-addgroup
-a always,exit -F path=/usr/sbin/useradd -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-useradd
-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-usermod
-a always,exit -F path=/usr/sbin/adduser -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-adduser

# Мониторинг монтирования
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts

# Мониторинг удаления файлов
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete

# Мониторинг изменений sudoers
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Мониторинг изменений модулей ядра
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# Неизменяемость конфигурации
-e 2
EOF

    # Перезапуск auditd
    systemctl enable auditd
    systemctl restart auditd
    
    log_success "Система аудита настроена"
}

# Настройка защиты от rootkit'ов
configure_rootkit_protection() {
    log_info "=== НАСТРОЙКА ЗАЩИТЫ ОТ ROOTKIT ==="
    
    # Настройка rkhunter
    cat > /etc/rkhunter.conf.local << 'EOF'
# Local configuration for rkhunter
UPDATE_MIRRORS=1
MIRRORS_MODE=0
WEB_CMD="/usr/bin/wget"
TMPDIR=/var/lib/rkhunter/tmp
DBDIR=/var/lib/rkhunter/db
SCRIPTDIR=/usr/share/rkhunter/scripts
LOGFILE=/var/log/rkhunter.log
APPEND_LOG=1
COPY_LOG_ON_ERROR=1
USE_SYSLOG=authpriv.notice
COLOR_SET2=1
AUTO_X_DETECT=1
WHITELISTED_IS_WHITE=1
ALLOW_SSH_ROOT_USER=no
ALLOW_SSH_PROT_V1=0
ENABLE_TESTS=ALL
DISABLE_TESTS=suspscan hidden_procs deleted_files packet_cap_apps apps
PKGMGR=DPKG
HASH_FUNC=sha256
HASH_FLD_IDX=3
PKGMGR_NO_VRFY=1
SCANROOTKITMODE=1
UNHIDETCP_OPTS=""
UNHIDEUDP_OPTS=""
INSTALLDIR=/usr
EOF

    # Обновление базы данных rkhunter
    rkhunter --update
    rkhunter --propupd
    
    # Настройка автоматической проверки
    cat > /etc/cron.daily/rkhunter << 'EOF'
#!/bin/bash
# Daily rkhunter scan
/usr/bin/rkhunter --cronjob --update --quiet
EOF
    chmod +x /etc/cron.daily/rkhunter
    
    # Настройка chkrootkit
    cat > /etc/cron.weekly/chkrootkit << 'EOF'
#!/bin/bash
# Weekly chkrootkit scan
/usr/sbin/chkrootkit | mail -s "chkrootkit report - $(hostname)" root
EOF
    chmod +x /etc/cron.weekly/chkrootkit
    
    log_success "Защита от rootkit настроена"
}

# Настройка антивируса ClamAV
configure_clamav() {
    log_info "=== НАСТРОЙКА АНТИВИРУСА CLAMAV ==="
    
    # Остановка сервисов для настройки
    systemctl stop clamav-daemon clamav-freshclam || true
    
    # Обновление конфигурации freshclam
    sed -i 's/^Example/#Example/' /etc/clamav/freshclam.conf
    sed -i 's/^#DatabaseMirror/DatabaseMirror/' /etc/clamav/freshclam.conf
    
    # Обновление конфигурации clamd
    sed -i 's/^Example/#Example/' /etc/clamav/clamd.conf
    sed -i 's/^#LocalSocket/LocalSocket/' /etc/clamav/clamd.conf
    sed -i 's/^#User/User/' /etc/clamav/clamd.conf
    
    # Обновление вирусных баз
    freshclam
    
    # Запуск сервисов
    systemctl enable clamav-daemon clamav-freshclam
    systemctl start clamav-freshclam
    systemctl start clamav-daemon
    
    # Создание скрипта ежедневного сканирования
    cat > /usr/local/bin/daily-clamscan.sh << 'EOF'
#!/bin/bash
# Daily ClamAV scan script

SCAN_DIR="/home /var /tmp"
LOG_FILE="/var/log/clamav/daily-scan.log"
INFECTED_FILE="/var/log/clamav/infected.log"

mkdir -p /var/log/clamav

echo "$(date): Starting ClamAV scan" >> "$LOG_FILE"

clamscan -r $SCAN_DIR \
    --log="$LOG_FILE" \
    --infected \
    --bell \
    --move=/var/quarantine \
    2>&1 | tee -a "$INFECTED_FILE"

if [ ${PIPESTATUS[0]} -eq 1 ]; then
    echo "$(date): VIRUS FOUND!" >> "$LOG_FILE"
    mail -s "VIRUS ALERT - $(hostname)" root < "$INFECTED_FILE"
fi

echo "$(date): ClamAV scan completed" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/daily-clamscan.sh
    mkdir -p /var/quarantine
    
    # Добавление в crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/daily-clamscan.sh") | crontab -
    
    log_success "ClamAV настроен и запущен"
}

# Настройка AIDE (Advanced Intrusion Detection Environment)
configure_aide() {
    log_info "=== НАСТРОЙКА AIDE ==="
    
    # Создание конфигурации AIDE
    cat > /etc/aide/aide.conf << 'EOF'
# AIDE configuration

# Database paths
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Verbose level
verbose=5

# Report format
report_url=file:/var/log/aide.log
report_url=stdout

# Rule definitions
All=p+i+n+u+g+s+m+c+md5+sha1+sha256+rmd160+tiger+haval+crc32
Norm=p+i+n+u+g+s+m+c+md5+sha256
Dir=p+i+n+u+g
PermsOnly=p+u+g
R=p+i+n+u+g+s+m+c+md5+sha256
L=p+i+n+u+g
E=
>=/p+u+g+i+n+S

# Directory monitoring rules
/boot   Norm
/bin    Norm
/sbin   Norm
/lib    Norm
/lib64  Norm
/opt    Norm
/usr    Norm
/root   Norm

# System directories
/etc    Norm

# Log directories (only permissions)
/var/log    Dir

# Exclude temporary and cache directories
!/var/tmp
!/var/cache
!/tmp
!/proc
!/sys
!/dev
!/run
!/var/run
!/var/lock
!/var/lib/aide/aide.db.new

# Home directories
/home   R

# Critical system files
/etc/passwd All
/etc/shadow All
/etc/group All
/etc/sudoers All
/etc/ssh/sshd_config All
/etc/crontab All
/etc/fstab All
/etc/hosts All
/etc/resolv.conf All
EOF

    # Инициализация базы данных AIDE
    aide --init
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    
    # Создание скрипта ежедневной проверки
    cat > /usr/local/bin/aide-check.sh << 'EOF'
#!/bin/bash
# AIDE daily check script

LOG_FILE="/var/log/aide-check.log"

echo "$(date): Starting AIDE check" >> "$LOG_FILE"

aide --check 2>&1 | tee -a "$LOG_FILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "$(date): AIDE detected changes!" >> "$LOG_FILE"
    mail -s "AIDE Alert - File system changes detected on $(hostname)" root < "$LOG_FILE"
fi

echo "$(date): AIDE check completed" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/aide-check.sh
    
    # Добавление в crontab
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/aide-check.sh") | crontab -
    
    log_success "AIDE настроен"
}

# Настройка защиты от сканирования портов (PSAD)
configure_psad() {
    log_info "=== НАСТРОЙКА PSAD (PORT SCAN ATTACK DETECTOR) ==="
    
    # Обновление конфигурации PSAD
    cat > /etc/psad/psad.conf << 'EOF'
# PSAD configuration

# Email settings
EMAIL_ADDRESSES     root@localhost;
HOSTNAME            $(hostname);
HOME_NET            127.0.0.0/8;

# Detection settings
PORT_RANGE_SCAN_THRESHOLD   1;
SCAN_TIMEOUT               3600;
DANGER_LEVEL1              5;
DANGER_LEVEL2              15;
DANGER_LEVEL3              150;
DANGER_LEVEL4              1500;
DANGER_LEVEL5              10000;

# Auto blocking
AUTO_IDS                   Y;
AUTO_IDS_DANGER_LEVEL      2;
AUTO_BLOCK_TIMEOUT         3600;

# Log settings
SYSLOG_DAEMON              Y;
SYSLOG_IDENTITY            psad;
SYSLOG_FACILITY            LOG_DAEMON;

# Signature updates
SIG_UPDATE_URL             http://www.cipherdyne.org/psad/signatures;
AUTO_PSAD_SIG_UPDATE       Y;

# DShield integration
ENABLE_DSHIELD_ALERTS      Y;
DSHIELD_ALERT_EMAIL        Y;

# Passive OS fingerprinting
ENABLE_PASSIVE_OS_FINGERPRINTING    Y;
P0F_FILE                   /etc/p0f/p0f.fp;

# whois lookups
ENABLE_WHOIS_LOOKUPS       Y;
WHOIS_TIMEOUT              60;

# Status monitoring
STATUS_INTERVAL            240;
EOF

    # Настройка автозапуска
    systemctl enable psad
    systemctl restart psad
    
    log_success "PSAD настроен и запущен"
}

# Настройка автообновлений безопасности
configure_security_updates() {
    log_info "=== НАСТРОЙКА АВТООБНОВЛЕНИЙ БЕЗОПАСНОСТИ ==="
    
    # Конфигурация unattended-upgrades
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
// Unattended-Upgrade::Origins-Pattern controls which packages are
// upgraded.
Unattended-Upgrade::Origins-Pattern {
        "origin=Ubuntu,archive=${distro_codename}-security,label=Ubuntu";
        "o=Ubuntu,a=${distro_codename}";
        "o=Ubuntu,a=${distro_codename}-updates";
        "o=Ubuntu,a=${distro_codename}-proposed";
        "o=Ubuntu,a=${distro_codename}-backports";
};

// Python regular expressions, matching packages to exclude from upgrading
Unattended-Upgrade::Package-Blacklist {
        // "vim";
        // "libc6-dev";
        // "nginx.*";
};

// Split the upgrade into the smallest possible chunks so that
// they can be interrupted with SIGTERM.
Unattended-Upgrade::MinimalSteps "true";

// Install all unattended-upgrades when the machine is shutting down
// instead of doing it in the background while the machine is running
Unattended-Upgrade::InstallOnShutdown "false";

// Send email to this address for problems or packages upgrades
// If empty or unset then no email is sent, make sure that you
// have a working mail setup on your system.
Unattended-Upgrade::Mail "root";

// Set this value to "true" to get emails only on errors.
Unattended-Upgrade::MailOnlyOnError "true";

// Remove unused automatically installed kernel-related packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Do automatic removal of new unused dependencies after the upgrade
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Do automatic removal of unused packages after the upgrade
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot *WITHOUT CONFIRMATION* if
// the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "false";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Use apt bandwidth limit feature
//Unattended-Upgrade::Acquire::http::Dl-Limit "70";

// Enable logging to syslog.
Unattended-Upgrade::SyslogEnable "true";

// Specify syslog facility.
Unattended-Upgrade::SyslogFacility "daemon";

// Download and install upgrades only on AC power
// (i.e. skip or gracefully stop updates on battery)
// Unattended-Upgrade::OnlyOnACPower "true";

// Download and install upgrades only on non-metered connection
// (i.e. skip or gracefully stop updates on a metered connection)
// Unattended-Upgrade::Skip-Updates-On-Metered-Connections "true";

// Verbose logging
// Unattended-Upgrade::Verbose "false";

// Print debugging information both in unattended-upgrades and
// in unattended-upgrade-shutdown
// Unattended-Upgrade::Debug "false";
EOF

    # Включение автообновлений
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

    # Тест конфигурации
    unattended-upgrade --dry-run --debug
    
    log_success "Автообновления безопасности настроены"
}

# Hardening ядра и системы
system_hardening() {
    log_info "=== СИСТЕМНОЕ УКРЕПЛЕНИЕ ==="
    
    # Настройка sysctl для безопасности
    cat > /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# Network security settings

# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# IP Redirect protection
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Send redirect protection
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Source route protection
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ping requests
net.ipv4.icmp_echo_ignore_all = 0

# Ignore directed pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0

# TCP settings
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Memory protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# Core dumps
fs.suid_dumpable = 0
kernel.core_uses_pid = 1

# Address space layout randomization
kernel.randomize_va_space = 2

# Shared memory
kernel.shmmax = 134217728
kernel.shmall = 2097152

# Swapping
vm.swappiness = 10

# File system
fs.file-max = 65536
EOF

    # Применение настроек sysctl
    sysctl -p /etc/sysctl.d/99-security-hardening.conf
    
    # Настройка limits.conf
    cat >> /etc/security/limits.conf << 'EOF'

# Security limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
* hard core 0
EOF

    # Отключение неиспользуемых сетевых протоколов
    cat > /etc/modprobe.d/blacklist-rare-network.conf << 'EOF'
# Blacklist rare network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF

    # Отключение неиспользуемых файловых систем
    cat > /etc/modprobe.d/blacklist-filesystems.conf << 'EOF'
# Blacklist rare filesystems
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
EOF

    log_success "Системное укрепление завершено"
}

# Создание скрипта мониторинга безопасности
create_security_monitor() {
    log_info "=== СОЗДАНИЕ МОНИТОРИНГА БЕЗОПАСНОСТИ ==="
    
    cat > /usr/local/bin/security-monitor.sh << 'EOF'
#!/bin/bash
# Security monitoring script

REPORT_FILE="/var/log/security-report-$(date +%Y%m%d).log"
ALERT_THRESHOLD=10

echo "=== SECURITY REPORT $(date) ===" > "$REPORT_FILE"

# Check failed login attempts
echo "Failed login attempts in last 24 hours:" >> "$REPORT_FILE"
grep "authentication failure" /var/log/auth.log | grep "$(date --date='1 day ago' +%b\ %d)" | wc -l >> "$REPORT_FILE"

# Check successful logins
echo "Successful logins in last 24 hours:" >> "$REPORT_FILE"
grep "Accepted" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l >> "$REPORT_FILE"

# Check UFW blocks
echo "UFW blocked connections in last 24 hours:" >> "$REPORT_FILE"
grep "UFW BLOCK" /var/log/ufw.log | grep "$(date +%b\ %d)" | wc -l >> "$REPORT_FILE"

# Check Fail2Ban bans
echo "Fail2Ban active bans:" >> "$REPORT_FILE"
fail2ban-client status | grep "Jail list" >> "$REPORT_FILE"

# Check listening ports
echo "Currently listening ports:" >> "$REPORT_FILE"
ss -tulnp >> "$REPORT_FILE"

# Check running processes
echo "Processes with network connections:" >> "$REPORT_FILE"
lsof -i -n -P >> "$REPORT_FILE"

# Check system load
echo "System load:" >> "$REPORT_FILE"
uptime >> "$REPORT_FILE"

# Check disk usage
echo "Disk usage:" >> "$REPORT_FILE"
df -h >> "$REPORT_FILE"

# Check memory usage
echo "Memory usage:" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE"

# Send alert if too many failed attempts
failed_attempts=$(grep "authentication failure" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)
if [ $failed_attempts -gt $ALERT_THRESHOLD ]; then
    echo "ALERT: $failed_attempts failed login attempts detected" | mail -s "Security Alert - $(hostname)" root
fi

echo "=== END REPORT ===" >> "$REPORT_FILE"
EOF

    chmod +x /usr/local/bin/security-monitor.sh
    
    # Добавление в crontab для запуска каждые 6 часов
    (crontab -l 2>/dev/null; echo "0 */6 * * * /usr/local/bin/security-monitor.sh") | crontab -
    
    log_success "Мониторинг безопасности настроен"
}

# Показать статус безопасности
show_security_status() {
    log_info "=== СТАТУС БЕЗОПАСНОСТИ ==="
    
    echo "🔥 Файрвол UFW:"
    ufw status | head -10
    
    echo -e "\n🚫 Fail2Ban статус:"
    if systemctl is-active --quiet fail2ban; then
        fail2ban-client status
    else
        echo "Не активен"
    fi
    
    echo -e "\n🛡️ Активные сервисы безопасности:"
    for service in ufw fail2ban auditd clamav-daemon psad; do
        status=$(systemctl is-active $service 2>/dev/null || echo "не установлен")
        echo "$service: $status"
    done
    
    echo -e "\n📊 Статистика за сегодня:"
    echo "Неудачные входы SSH: $(grep "Failed password" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)"
    echo "Успешные входы SSH: $(grep "Accepted" /var/log/auth.log | grep "$(date +%b\ %d)" | wc -l)"
    echo "Заблокированные соединения UFW: $(grep "UFW BLOCK" /var/log/ufw.log 2>/dev/null | grep "$(date +%b\ %d)" | wc -l)"
    
    echo -e "\n🌐 Открытые порты:"
    ss -tulnp | grep LISTEN | head -10
}

# Интерактивная настройка
interactive_setup() {
    log_info "=== ИНТЕРАКТИВНАЯ НАСТРОЙКА БЕЗОПАСНОСТИ ==="
    
    # SSH порт
    read -p "SSH порт [22]: " ssh_port
    ssh_port=${ssh_port:-22}
    
    # Дополнительные сервисы
    echo "Выберите дополнительные сервисы для разрешения в файрволе:"
    echo "Доступные: http,https,dns,ntp,smtp,mysql,postgres или номера портов"
    read -p "Сервисы (через запятую): " allowed_services
    
    # Компоненты безопасности
    read -p "Установить и настроить ClamAV антивирус? (y/n) [y]: " install_clamav
    install_clamav=${install_clamav:-y}
    
    read -p "Настроить AIDE для мониторинга файлов? (y/n) [y]: " setup_aide
    setup_aide=${setup_aide:-y}
    
    read -p "Настроить систему аудита? (y/n) [y]: " setup_audit
    setup_audit=${setup_audit:-y}
    
    read -p "Настроить защиту от rootkit? (y/n) [y]: " setup_rootkit
    setup_rootkit=${setup_rootkit:-y}
    
    read -p "Настроить PSAD для защиты от сканирования портов? (y/n) [n]: " setup_psad_choice
    setup_psad_choice=${setup_psad_choice:-n}
    
    echo
    log_info "=== ПОДТВЕРЖДЕНИЕ НАСТРОЕК ==="
    echo "SSH порт: $ssh_port"
    echo "Разрешенные сервисы: ${allowed_services:-нет}"
    echo "ClamAV: $install_clamav"
    echo "AIDE: $setup_aide"
    echo "Аудит: $setup_audit"
    echo "Защита от rootkit: $setup_rootkit"
    echo "PSAD: $setup_psad_choice"
    
    read -p "Продолжить? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Настройка отменена"
        exit 0
    fi
    
    # Выполнение настройки
    install_security_packages
    configure_ufw "$ssh_port" "$allowed_services"
    configure_fail2ban "$ssh_port"
    configure_security_updates
    system_hardening
    create_security_monitor
    
    if [[ $install_clamav =~ ^[Yy]$ ]]; then
        configure_clamav
    fi
    
    if [[ $setup_aide =~ ^[Yy]$ ]]; then
        configure_aide
    fi
    
    if [[ $setup_audit =~ ^[Yy]$ ]]; then
        configure_auditd
    fi
    
    if [[ $setup_rootkit =~ ^[Yy]$ ]]; then
        configure_rootkit_protection
    fi
    
    if [[ $setup_psad_choice =~ ^[Yy]$ ]]; then
        configure_psad
    fi
    
    log_success "Настройка безопасности завершена!"
    show_security_status
}

# Функция помощи
show_help() {
    cat << EOF
Security & Firewall Setup Script v1.0

ИСПОЛЬЗОВАНИЕ:
    $0 [КОМАНДА] [ПАРАМЕТРЫ]

КОМАНДЫ:
    interactive          - Интерактивная настройка всех компонентов
    firewall [PORT]      - Настройка только UFW файрвола
    fail2ban [PORT]      - Настройка только Fail2Ban
    antivirus           - Настройка только ClamAV
    audit               - Настройка только системы аудита
    hardening           - Системное укрепление
    monitor             - Настройка мониторинга безопасности
    status              - Показать статус безопасности
    help                - Показать эту справку

ПРИМЕРЫ:
    $0 interactive               # Полная интерактивная настройка
    $0 firewall 2222            # Настройка UFW с SSH на порту 2222
    $0 status                   # Проверка статуса безопасности

ФУНКЦИИ:
    ✓ UFW файрвол с расширенными правилами
    ✓ Fail2Ban защита от брутфорс атак
    ✓ ClamAV антивирус с автосканированием
    ✓ AIDE мониторинг изменений файлов
    ✓ Система аудита событий
    ✓ Защита от rootkit (rkhunter, chkrootkit)
    ✓ PSAD защита от сканирования портов
    ✓ Автообновления безопасности
    ✓ Системное укрепление (sysctl, limits)
    ✓ Мониторинг и уведомления
EOF
}

# Главная функция
main() {
    check_root
    
    case "${1:-interactive}" in
        "interactive"|"i")
            interactive_setup
            ;;
        "firewall"|"f")
            install_security_packages
            configure_ufw "${2:-22}" "${3:-}"
            ;;
        "fail2ban"|"fb")
            install_security_packages
            configure_fail2ban "${2:-22}"
            ;;
        "antivirus"|"av")
            configure_clamav
            ;;
        "audit"|"a")
            configure_auditd
            ;;
        "hardening"|"h")
            system_hardening
            ;;
        "monitor"|"m")
            create_security_monitor
            ;;
        "status"|"s")
            show_security_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'log_error "Скрипт прерван"; exit 1' INT TERM

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
