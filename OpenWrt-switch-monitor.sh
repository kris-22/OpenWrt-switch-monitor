#!/bin/bash

# telegram bot token
telegram_bot_token=""
telegram_chat_id=""

# Plik do przechowywania danych CSV
CSV_FILE="filePath/file.csv"

# Pobierz aktualne dane
DATA=$(ssh root@192.168.1.1 "swconfig dev switch0 show")

send_telegram_notification() {
    local message=$(echo $1 | sed 's/-/\\-/g' | sed 's/"//g')
    curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" \
        -d "chat_id=$telegram_chat_id" \
        -d "parse_mode=markdownV2" \
        -d "text=$message" > /dev/null
}
# Funkcja sprawdzająca zmiany w danych
check_changes() {
    local previous_data="$1"
    local current_data="$2"
    local interface="$3"

    # Porównaj poprzednie i aktualne dane
    if [ "$previous_data" != "$current_data" ]; then
        echo "Zmiany dla interfejsu $interface:"
        diff <(echo "$previous_data") <(echo "$current_data") | sed "s/^[0-9a-f]\{8\}/$interface/g"
        # Wyślij powiadomienie na Telegramie o zmianie statusu
        send_telegram_notification "Zmiana statusu dla interfejsu *$interface* %0A %0Az: _ $previous_data _ %0A %0Ana: _ $current_data _ "
    # else
        # echo "Brak zmian dla interfejsu $interface."
    fi
}

# Sprawdź, czy plik z danymi istnieje
if [ -e "$CSV_FILE" ]; then
    # Odczytaj poprzednie dane z pliku CSV
    PREVIOUS_DATA=$(cat "$CSV_FILE")
else
    echo "Plik z danymi nie istnieje. Tworzenie pliku..."
    echo "interface,data" > "$CSV_FILE"
fi

# Zapisz aktualne dane do pliku CSV z odpowiednimi nagłówkami dla każdego interfejsu
INTERFACES=("lan4" "lan3" "lan2" "lan1" "wan" )
updated_data="interface,data" # Nowe dane, które będziemy edytować

for ((i = 0; i < ${#INTERFACES[@]}; i++)); do
    interface=${INTERFACES[i]}
    current_data=$(echo "$DATA" | grep -E "port:$((i + 1))+")
    # echo "Aktualne dane dla interfejsu $interface: $current_data"
    csv_line="\"$interface\",\"$(echo "$current_data" | sed 's/\"/""/g')\""

    # Dodaj dane do zmiennej updated_data, a nie do pliku
    updated_data="$updated_data\n$csv_line"

    # Porównaj zmiany dla każdego interfejsu
    if [ -n "$PREVIOUS_DATA" ]; then
        previous_interface_data=$(echo "$PREVIOUS_DATA" | grep "\"$interface\",")
        check_changes "$previous_interface_data" "$csv_line" "$interface"
    fi
done

# Zapisz edytowane dane do pliku CSV
echo -e "$updated_data" > "$CSV_FILE"