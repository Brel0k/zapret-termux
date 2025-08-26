#!/bin/sh
set -e  

# --- Fix PATH for Termux ---
if [ -d "/data/data/com.termux/files/usr/bin" ]; then
    export PATH="/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets:$PATH"
    GIT="/data/data/com.termux/files/usr/bin/git"
    BASH="/data/data/com.termux/files/usr/bin/bash"
else
    GIT="$(command -v git || echo git)"
    BASH="$(command -v bash || echo bash)"
fi

install_dependencies() {
    kernel="$(uname -s)"

    if [ "$kernel" = "Linux" ]; then
        # Проверка на Termux
        if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ] && [ -x "$PREFIX/bin/pkg" ]; then
            echo "Обнаружен Termux (Android)"
            pkg update -y && pkg install -y git bash curl iptables
            return
        fi

        [ -f /etc/os-release ] && . /etc/os-release || { echo "Не удалось определить ОС"; exit 1; }

        SUDO="${SUDO:-}"

        find_package_manager() {
            case "$1" in
                arch|artix|cachyos|endeavouros|manjaro|garuda) echo "$SUDO pacman -Syu --noconfirm && $SUDO pacman -S --noconfirm --needed git" ;;
                debian|ubuntu|mint) echo "$SUDO apt update -y && $SUDO apt install -y git" ;;
                fedora|almalinux|rocky) echo "$SUDO dnf check-update -y && $SUDO dnf install -y git" ;;
                void)      echo "$SUDO xbps-install -S && $SUDO xbps-install -y git" ;;
                gentoo)    echo "$SUDO emerge --sync --quiet && $SUDO emerge --ask=n dev-vcs/git app-shells/bash" ;;
                opensuse)  echo "$SUDO zypper refresh && $SUDO zypper install git" ;;
                openwrt)   echo "$SUDO opkg update && $SUDO opkg install git git-http bash" ;;
                altlinux)  echo "$SUDO apt-get update -y && $SUDO apt-get install -y git bash" ;;
                alpine)    echo "$SUDO apk update && $SUDO apk add git bash" ;;
                *)         echo "" ;;
            esac
        }

        install_cmd="$(find_package_manager "$ID")"
        if [ -z "$install_cmd" ] && [ -n "$ID_LIKE" ]; then
            for like in $ID_LIKE; do
                install_cmd="$(find_package_manager "$like")" && [ -n "$install_cmd" ] && break
            done
        fi

        if [ -n "$install_cmd" ]; then
            eval "$install_cmd"
        else
            echo "Неизвестная ОС: ${ID:-Неизвестно}"
            echo "Установите git и bash самостоятельно."
            sleep 2
        fi
    elif [ "$kernel" = "Darwin" ]; then
        echo "macOS не поддерживается на данный момент."
        exit 1
    else
        echo "Неизвестная ОС: $kernel"
        echo "Установите git и bash самостоятельно."
        sleep 2
    fi
}

# Проверка root FS только если не Termux
if ! { [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; }; then
    if [ "$(awk '$2 == "/" {print $4}' /proc/mounts)" = "ro" ]; then
        echo "Файловая система только для чтения, не могу продолжать."
        exit 1
    fi
fi

# Определение SUDO
if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; then
    # Termux: используем su, если доступен
    if command -v su > /dev/null 2>&1; then
        SUDO="su -c"
    else
        SUDO=""
    fi
else
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
    else
        if command -v sudo > /dev/null 2>&1; then
            SUDO="sudo"
        elif command -v doas > /dev/null 2>&1; then
            SUDO="doas"
        elif command -v su > /dev/null 2>&1; then
            SUDO="su -c"
        else
            echo "Скрипт не может быть выполнен не от имени суперпользователя."
            exit 1
        fi
    fi
fi

if ! command -v "$GIT" > /dev/null 2>&1; then
    install_dependencies
fi

# В Termux ставим в $HOME, в Linux — в /opt
if [ -n "$PREFIX" ] && [ -d "$PREFIX/bin" ]; then
    INSTALL_DIR="$HOME/zapret.installer"
else
    INSTALL_DIR="/opt/zapret.installer"
fi

if [ ! -d "$INSTALL_DIR" ]; then
    $SUDO "$GIT" clone https://github.com/Snowy-Fluffy/zapret.installer.git "$INSTALL_DIR"
else
    cd "$INSTALL_DIR" || exit
    if ! $SUDO "$GIT" pull; then
        echo "Ошибка при обновлении. Удаляю репозиторий и клонирую заново..."
        $SUDO rm -rf "$INSTALL_DIR"
        $SUDO "$GIT" clone https://github.com/Snowy-Fluffy/zapret.installer.git "$INSTALL_DIR"
    fi
fi

# Патчим все скрипты: заменяем /opt/zapret.installer → $INSTALL_DIR
find "$INSTALL_DIR" -type f -exec sed -i "s|/opt/zapret.installer|$INSTALL_DIR|g" {} +

$SUDO chmod +x "$INSTALL_DIR/zapret-control.sh"
exec "$BASH" "$INSTALL_DIR/zapret-control.sh"
