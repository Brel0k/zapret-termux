#!/bin/bash

# Функция для установки wget и git в Termux
install_with_pkg() {
  echo "Обнаружен Termux, устанавливаем wget и git..."
  pkg update -y
  pkg install -y wget git
}

# Проверка и установка зависимостей
if command -v pkg &>/dev/null; then
  install_with_pkg
else
  echo "Не удалось определить пакетный менеджер Termux (pkg)."
  if command -v wget &>/dev/null && command -v git &>/dev/null; then
    echo "wget и git уже установлены, продолжаем..."
  else
    echo "Необходимо установить wget и git вручную с помощью 'pkg install wget git'."
    exit 1
  fi
fi

# Создаем временную директорию, если она не существует
mkdir -p "$HOME/tmp"
# Очистка временной директории с защитой от ошибок
rm -rf "$HOME/tmp/*" 2>/dev/null || true

# Бэкап zapret, если он существует
if [ -d "$HOME/opt/zapret" ]; then
  echo "Создание резервной копии существующего zapret..."
  cp -r "$HOME/opt/zapret" "$HOME/opt/zapret.bak" 2>/dev/null || {
    echo "Предупреждение: не удалось создать резервную копию zapret."
  }
fi
rm -rf "$HOME/opt/zapret" 2>/dev/null || true

# Получение последней версии zapret с GitHub API
echo "Определение последней версии zapret..."
ZAPRET_VERSION=$(curl -s "https://api.github.com/repos/bol-van/zapret/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$ZAPRET_VERSION" ]; then
  echo "Не удалось получить версию через GitHub API. Используем git ls-remote..."
  ZAPRET_VERSION=$(git ls-remote --tags https://github.com/bol-van/zapret.git | 
                  grep -v '\^{}' | 
                  awk -F/ '{print $NF}' | 
                  sort -V | 
                  tail -n 1)
  if [ -z "$ZAPRET_VERSION" ]; then
    echo "Ошибка: не удалось определить последнюю версию zapret."
    exit 1
  fi
fi

echo "Последняя версия zapret: $ZAPRET_VERSION"

# Скачивание последнего релиза zapret
echo "Скачивание последнего релиза zapret..."
if ! wget -O "$HOME/tmp/zapret-$ZAPRET_VERSION.tar.gz" "https://github.com/bol-van/zapret/releases/download/$ZAPRET_VERSION/zapret-$ZAPRET_VERSION.tar.gz"; then
  echo "Ошибка: не удалось скачать zapret."
  exit 1
fi

# Распаковка архива
echo "Распаковка zapret..."
if ! tar -xvf "$HOME/tmp/zapret-$ZAPRET_VERSION.tar.gz" -C "$HOME/tmp"; then
  echo "Ошибка: не удалось распаковать zapret."
  exit 1
fi

# Версия без 'v' в начале для работы с директорией
ZAPRET_DIR_VERSION=$(echo "$ZAPRET_VERSION" | sed 's/^v//')
echo "Определение пути распакованного архива..."

# Проверяем наличие директорий с разными вариантами именования
if [ -d "$HOME/tmp/zapret-$ZAPRET_DIR_VERSION" ]; then
  ZAPRET_EXTRACT_DIR="$HOME/tmp/zapret-$ZAPRET_DIR_VERSION"
elif [ -d "$HOME/tmp/zapret-$ZAPRET_VERSION" ]; then
  ZAPRET_EXTRACT_DIR="$HOME/tmp/zapret-$ZAPRET_VERSION"
else
  ZAPRET_EXTRACT_DIR=$(find "$HOME/tmp" -type d -name "zapret-*" | head -n 1)
  if [ -z "$ZAPRET_EXTRACT_DIR" ]; then
    echo "Ошибка: не удалось найти распакованную директорию zapret."
    echo "Содержимое $HOME/tmp:"
    ls -la "$HOME/tmp"
    exit 1
  fi
fi

echo "Найден распакованный каталог: $ZAPRET_EXTRACT_DIR"

# Создание директории $HOME/opt, если она не существует
mkdir -p "$HOME/opt"

# Перемещение zapret в $HOME/opt/zapret
echo "Перемещение zapret в $HOME/opt/zapret..."
if ! mv "$ZAPRET_EXTRACT_DIR" "$HOME/opt/zapret"; then
  echo "Ошибка: не удалось переместить zapret в $HOME/opt/zapret."
  exit 1
fi

# Клонирование репозитория с конфигами
echo "Клонирование репозитория с конфигами..."
if ! git clone https://github.com/kartavkun/zapret-discord-youtube.git "$HOME/zapret-configs"; then
  rm -rf "$HOME/zapret-configs" 2>/dev/null
  if ! git clone https://github.com/kartavkun/zapret-discord-youtube.git "$HOME/zapret-configs"; then
    echo "Ошибка: не удалось клонировать репозиторий с конфигами."
    exit 1
  fi
fi

# Копирование hostlists
echo "Копирование hostlists..."
mkdir -p "$HOME/opt/zapret/hostlists"
if ! cp -r "$HOME/zapret-configs/hostlists" "$HOME/opt/zapret/"; then
  echo "Ошибка: не удалось скопировать hostlists."
  exit 1
fi

# Создание директории для конфига
mkdir -p "$HOME/opt/zapret/config"

# Попытка исправить install.sh перед запуском
echo "Проверка и исправление install.sh для Termux..."
if [ -f "$HOME/zapret-configs/install.sh" ]; then
  # Заменяем /opt/zapret на $HOME/opt/zapret в install.sh
  sed -i "s|/opt/zapret|$HOME/opt/zapret|g" "$HOME/zapret-configs/install.sh"
  # Делаем скрипт исполняемым
  chmod +x "$HOME/zapret-configs/install.sh"
else
  echo "Ошибка: файл install.sh не найден в $HOME/zapret-configs."
  exit 1
fi

# Пропускаем настройку IP forwarding и других системных параметров, так как они требуют root
echo "Пропуск настройки системных параметров (например, IP forwarding), так как они требуют root-доступа."

# Запуск install.sh с обработкой ошибок
echo "Запуск install.sh..."
if ! bash "$HOME/zapret-configs/install.sh"; then
  echo "Ошибка: не удалось запустить install.sh."
  echo "Возможные причины:"
  echo "- Скрипт install.sh содержит команды, требующие root-доступа (например, iptables, nftables, systemctl)."
  echo "- Неправильные пути или отсутствующие файлы."
  echo "Рекомендации:"
  echo "1. Проверьте содержимое $HOME/zapret-configs/install.sh."
  echo "2. Убедитесь, что все зависимости установлены (например, pkg install iptables если требуется)."
  echo "3. Если у вас есть root-доступ, установите 'tsu' (pkg install tsu) и попробуйте снова."
  echo "4. Вручную замените пути в install.sh, если они используют /opt/zapret."
  exit 1
fi

echo "Установка завершена успешно!"
