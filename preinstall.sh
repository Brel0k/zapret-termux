#!/bin/sh
set -e

# --- Fix PATH for Termux ---
export PATH="/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets:$PATH"
GIT="/data/data/com.termux/files/usr/bin/git"
BASH="/data/data/com.termux/files/usr/bin/bash"
SED="/data/data/com.termux/files/usr/bin/sed"

# --- Установка зависимостей ---
pkg update -y
pkg upgrade -y
pkg install -y tsu python git coreutils curl

# --- Путь установки ---
INSTALL_DIR="$HOME/zapret-termux"

# --- Клонируем репозиторий обычным пользователем ---
if [ ! -d "$INSTALL_DIR" ]; then
    $GIT clone https://github.com/Brel0k/zapret-termux.git "$INSTALL_DIR"
else
    cd "$INSTALL_DIR" || exit
    # Pull только если не root, иначе меняем владельца
    if [ "$(id -u)" -ne 0 ]; then
        $GIT pull || echo "Ошибка обновления, продолжаем..."
    else
        chown -R $(id -u):$(id -g) "$INSTALL_DIR"
    fi
fi

cd "$INSTALL_DIR" || exit

# --- Даем права на исполнение ---
chmod +x main.sh

# --- Патчим все скрипты (исключая .git), заменяем /opt/... → INSTALL_DIR ---
find "$INSTALL_DIR" -type f ! -path "*/.git/*" -exec $SED -i "s|/opt/zapret.installer|$INSTALL_DIR|g" {} +

# --- Запуск main.sh через Termux bash ---
exec "$BASH" "$INSTALL_DIR/main.sh"
