# 1. Обновление Termux
pkg update -y
pkg upgrade -y

# 2. Установка зависимостей
pkg install -y tsu python git coreutils curl

# 3. Клонируем репозиторий обычным пользователем
git clone https://github.com/Brel0k/zapret-termux.git ~/zapret-termux

cd ~/zapret-termux

# 4. Даем права на исполнение
chmod +x main.sh

# 5. Запускаем скрипт
./main.sh
