# 🚀 Ubuntu Server Automation Suite

Комплексный набор скриптов для автоматической настройки и укрепления безопасности Ubuntu Server.

## 📋 Состав пакета

### Основные скрипты
- `setup-wizard.sh` - Интерактивный мастер настройки
- `main-setup.sh` - Основной скрипт автоматической настройки
- `ssh-hardening.sh` - Усиленная настройка SSH безопасности
- `security-firewall.sh` - Настройка файрвола и системы безопасности

### Модульная структура
```
ubuntu-automation/
├── setup-wizard.sh          # Главный интерактивный мастер
├── main-setup.sh            # Основной orchestrator
├── ssh-hardening.sh         # SSH безопасность
├── security-firewall.sh     # Файрвол и защита
├── README.md                # Эта документация
└── configs/                 # Готовые конфигурации
    ├── ufw-rules.conf
    ├── fail2ban-custom.conf
    └── ssh-hardened.conf
```

## 🎯 Возможности

### ✅ Полностью автоматизируемые процессы (90%)
- **Обновление системы** - полное обновление пакетов
- **Установка пакетов** - системные и пользовательские пакеты
- **Настройка hostname и timezone** - системная идентификация
- **SSH сервер** - безопасная конфигурация
- **Файрвол UFW** - правила безопасности
- **Fail2Ban** - защита от брутфорс атак
- **Создание пользователя** - с правами sudo
- **Автообновления** - безопасные обновления
- **Логирование** - централизованные логи
- **Мониторинг** - система отслеживания событий

### 🔒 Компоненты безопасности
- **SSH Hardening** - современные алгоритмы шифрования
- **UFW Firewall** - интеллектуальные правила
- **Fail2Ban** - защита от атак
- **ClamAV** - антивирус с автосканированием
- **AIDE** - мониторинг изменений файлов
- **Auditd** - система аудита
- **Rootkit Protection** - rkhunter + chkrootkit
- **PSAD** - защита от сканирования портов
- **System Hardening** - укрепление ядра

### ⚠️ Требует ручного вмешательства
- Первое подключение к серверу
- Передача SSH-ключей
- Финальная проверка доступа
- Выбор критически важных паролей

## 🚀 Быстрый старт

### Вариант 1: Полная автоматическая настройка
```bash
# Скачивание и запуск мастера настройки
wget -O setup-wizard.sh https://raw.githubusercontent.com/your-repo/setup-wizard.sh
chmod +x setup-wizard.sh
sudo ./setup-wizard.sh
```

### Вариант 2: Пошаговая настройка
```bash
# 1. Базовая настройка системы
sudo ./main-setup.sh

# 2. Усиленная настройка SSH
sudo ./ssh-hardening.sh interactive

# 3. Настройка безопасности и файрвола
sudo ./security-firewall.sh interactive
```

### Вариант 3: Быстрая настройка с параметрами
```bash
# Быстрая настройка SSH на порту 2222 для пользователя myuser
sudo ./ssh-hardening.sh quick 2222 myuser

# Быстрая настройка файрвола с HTTP/HTTPS
sudo ./security-firewall.sh firewall 2222 http,https
```

## 📖 Подробные инструкции

### Setup Wizard (Рекомендуемый способ)

```bash
sudo ./setup-wizard.sh
```

**Что он делает:**
1. Проверяет совместимость системы
2. Создает резервные копии конфигураций
3. Собирает информацию о желаемых настройках
4. Запускает автоматическую настройку
5. Создает отчет о проделанной работе

**Интерактивные параметры:**
- Hostname сервера
- Временная зона
- Создание нового пользователя
- SSH настройки (порт, ключи)
- Дополнительные пакеты

### SSH Hardening

```bash
# Интерактивная настройка
sudo ./ssh-hardening.sh interactive

# Быстрая настройка
sudo ./ssh-hardening.sh quick [PORT] [USERNAME]

# Аудит безопасности SSH
sudo ./ssh-hardening.sh audit

# Просмотр текущих настроек
sudo ./ssh-hardening.sh info
```

**Функции SSH Hardening:**
- Отключение root доступа
- Современные алгоритмы шифрования
- Ограничение попыток входа
- Настройка таймаутов
- Двухфакторная аутентификация (опционально)
- Ограничения по IP (опционально)
- Детальное логирование
- Мониторинг подозрительной активности

### Security & Firewall

```bash
# Полная интерактивная настройка
sudo ./security-firewall.sh interactive

# Настройка только файрвола
sudo ./security-firewall.sh firewall [SSH_PORT] [SERVICES]

# Настройка только Fail2Ban
sudo ./security-firewall.sh fail2ban [SSH_PORT]

# Проверка статуса безопасности
sudo ./security-firewall.sh status
```

**Компоненты безопасности:**
- **UFW** - простой файрвол с умными правилами
- **Fail2Ban** - защита от брутфорс атак
- **ClamAV** - антивирус с ежедневным сканированием
- **AIDE** - мониторинг целостности файлов
- **Auditd** - система аудита событий
- **rkhunter/chkrootkit** - защита от rootkit
- **PSAD** - детектор сканирования портов
- **System Hardening** - укрепление системы

## ⚙️ Настройка под свои нужды

### Переменные окружения

```bash
# SSH настройки
export SSH_PORT=2222
export SSH_USER=myuser
export DISABLE_PASSWORD_AUTH=yes

# Безопасность
export INSTALL_CLAMAV=yes
export SETUP_AIDE=yes
export ENABLE_2FA=no

# Сервисы
export ALLOWED_SERVICES="http,https,dns"
```

### Пользовательские конфигурации

Создайте файл `/tmp/setup-vars` с вашими настройками:
```bash
SERVER_HOSTNAME="my-server"
TIMEZONE="Europe/Moscow"
USERNAME="admin"
SSH_PORT="2222"
DISABLE_PASSWORD_AUTH="yes"
INSTALL_BASIC_TOOLS="yes"
INSTALL_DOCKER="yes"
```

## 📊 Что происходит после настройки

### Автоматические процессы
- **Ежедневно в 02:00** - ClamAV сканирование
- **Ежедневно в 03:00** - AIDE проверка целостности
- **Каждые 6 часов** - отчет о безопасности
- **Еженедельно** - обновление антивирусных баз
- **Автоматически** - установка обновлений безопасности

### Логи и мониторинг
```bash
# Основной лог установки
tail -f /var/log/ubuntu-setup.log

# SSH мониторинг
tail -f /var/log/ssh-detailed.log

# Отчеты безопасности
ls /var/log/security-report-*.log

# Статус Fail2Ban
sudo fail2ban-client status

# Статус UFW
sudo ufw status verbose
```

### Важные файлы после установки
```bash
/root/setup-report-YYYYMMDD-HHMMSS.txt    # Отчет о настройке
/root/USERNAME_credentials.txt            # Пароль нового пользователя
/root/config-backup-YYYYMMDD-HHMMSS/      # Резервные копии
/var/log/ubuntu-setup.log                 # Лог установки
```

## 🛡️ Проверка безопасности

### Ручная проверка после настройки
```bash
# 1. Проверка SSH в новом терминале
ssh username@server-ip -p SSH_PORT

# 2. Проверка файрвола
sudo ufw status verbose

# 3. Проверка Fail2Ban
sudo fail2ban-client status

# 4. Проверка открытых портов
sudo ss -tulnp | grep LISTEN

# 5. Проверка активных сервисов
sudo systemctl list-units --type=service --state=active

# 6. Аудит SSH
sudo ./ssh-hardening.sh audit

# 7. Статус безопасности
sudo ./security-firewall.sh status
```

### Автоматический аудит
```bash
# Запуск полного аудита безопасности
sudo ./security-firewall.sh audit

# Проверка SSH конфигурации
sudo ./ssh-hardening.sh audit
```

## 🔧 Устранение проблем

### Распространенные проблемы

**1. Не могу подключиться по SSH после настройки**
```bash
# Проверьте порт SSH
sudo grep "Port" /etc/ssh/sshd_config

# Проверьте UFW правила
sudo ufw status | grep SSH_PORT

# Временно разрешите стандартный порт
sudo ufw allow 22/tcp
```

**2. Fail2Ban блокирует мой IP**
```bash
# Посмотреть заблокированные IP
sudo fail2ban-client status sshd

# Разблокировать IP
sudo fail2ban-client set sshd unbanip YOUR_IP
```

**3. Ошибки в SSH конфигурации**
```bash
# Проверить конфигурацию
sudo sshd -t

# Восстановить из резервной копии
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart ssh
```

### Откат изменений
```bash
# Восстановление из резервной копии
sudo cp /root/config-backup-*/sshd_config /etc/ssh/
sudo cp /root/config-backup-*/ufw.conf /etc/ufw/
sudo systemctl restart ssh ufw
```

## 📈 Мониторинг и отчеты

### Встроенные отчеты
- **Ежедневные отчеты** - `/var/log/security-report-*.log`
- **SSH активность** - `/var/log/ssh-detailed.log`
- **Fail2Ban логи** - `/var/log/fail2ban.log`
- **UFW логи** - `/var/log/ufw.log`

### Настройка уведомлений
```bash
# Настройка email уведомлений
echo "your-email@domain.com" | sudo tee /etc/aliases
sudo newaliases

# Тест отправки уведомлений
echo "Test security alert" | mail -s "Test Alert" root
```

## 🎁 Дополнительные возможности

### Интеграция с облачными провайдерами
- **Cloud-init** совместимость
- **Terraform** модули
- **Ansible** плейбуки
- **Docker** контейнеризация

### Расширения и плагины
- **VPN настройка** (WireGuard/OpenVPN)
- **Веб-сервер** конфигурации (Nginx/Apache)
- **База данных** настройки (MySQL/PostgreSQL)
- **Контейнеры** (Docker/Kubernetes)

## 📋 Требования системы

### Минимальные требования
- **ОС**: Ubuntu 20.04 LTS или новее
- **RAM**: 1 GB (рекомендуется 2 GB)
- **Диск**: 10 GB свободного места
- **Сеть**: интернет для загрузки пакетов

### Поддерживаемые версии Ubuntu
- ✅ Ubuntu 20.04 LTS (Focal Fossa)
- ✅ Ubuntu 22.04 LTS (Jammy Jellyfish)
- ✅ Ubuntu 24.04 LTS (Noble Numbat)

## 🤝 Поддержка и помощь

### Получение помощи
```bash
# Справка по скриптам
./setup-wizard.sh help
./ssh-hardening.sh help
./security-firewall.sh help

# Проверка логов
sudo tail -f /var/log/ubuntu-setup.log
```

### Сообщение о проблемах
При возникновении проблем приложите:
1. Версию Ubuntu (`lsb_release -a`)
2. Логи установки (`/var/log/ubuntu-setup.log`)
3. Конфигурацию SSH (`sudo sshd -T`)
4. Статус сервисов (`sudo systemctl status ssh ufw fail2ban`)

## 📄 Лицензия

MIT License - свободное использование и модификация.

## 🔄 Обновления

### Проверка обновлений скриптов
```bash
# Скачивание последней версии
wget -O update-check.sh https://raw.githubusercontent.com/your-repo/update-check.sh
chmod +x update-check.sh
./update-check.sh
```

## 💡 Лучшие практики

### Перед запуском скриптов
1. **Создайте снапшот** сервера (если возможно)
2. **Подготовьте SSH ключи** заранее
3. **Запишите текущие настройки** сети
4. **Убедитесь в наличии консольного доступа**

### После настройки
1. **Протестируйте SSH подключение** в новом терминале
2. **Сохраните учетные данные** в безопасном месте
3. **Настройте мониторинг** и уведомления
4. **Создайте расписание резервного копирования**

### Безопасность
1. **Регулярно обновляйте** систему
2. **Мониторьте логи** на подозрительную активность
3. **Проводите аудит** настроек безопасности
4. **Обновляйте SSH ключи** периодически

---

**🎯 Цель проекта**: Превратить процесс настройки Ubuntu Server из многочасовой рутины в быструю автоматизированную процедуру с максимальным уровнем безопасности.

**⏱️ Экономия времени**: От 2-3 часов ручной настройки до 15-30 минут автоматизированной установки.

**🛡️ Уровень безопасности**: Enterprise-grade безопасность из коробки.

---

*Сделано с ❤️ для сообщества системных администраторов*
