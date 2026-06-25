#!/usr/bin/env bash
# Limpeza conservadora de logs, temporarios e caches antigos do usuario.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-clean-lib.sh"

DAYS=30
EMPTY_TRASH=0

usage() {
  cat <<'EOF'
Limpa logs, temporarios e caches antigos do usuario de forma conservadora.

Opcoes:
  --yes           nao pede confirmacao
  --dry-run       mostra o que seria removido
  --days N        remove itens antigos com mais de N dias (padrao: 30)
  --empty-trash   esvazia ~/.Trash
  -h, --help      mostra esta ajuda

Exemplo:
  bash clean-system-safe.sh --dry-run --days 30
EOF
}

while [[ $# -gt 0 ]]; do
  if parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --days=*) DAYS="${1#*=}" ;;
    --days)
      if [[ -n "${2-}" ]]; then DAYS="$2"; shift; else echo "Faltou valor para --days"; exit 2; fi
      ;;
    --empty-trash) EMPTY_TRASH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
  echo "--days precisa ser um numero positivo."
  exit 2
fi

echo "== Limpeza segura do sistema =="
echo "Removendo apenas itens com mais de $DAYS dias onde aplicavel."

echo "-- Temporarios"
rm_find_older_than "${TMPDIR:-/tmp}" "$DAYS" 1

echo "-- Logs do usuario"
rm_find_older_than "$HOME/Library/Logs" "$DAYS" 1
rm_find_older_than "$HOME/Library/Logs/DiagnosticReports" "$DAYS" 1

echo "-- Crash reports"
rm_find_older_than "$HOME/Library/Application Support/CrashReporter" "$DAYS" 1

echo "-- QuickLook e caches leves"
rm_safe "$HOME/Library/Caches/com.apple.QuickLook.thumbnailcache"
rm_find_older_than "$HOME/Library/Caches" "$DAYS" 1

if [[ $EMPTY_TRASH -eq 1 ]]; then
  echo "-- Lixeira"
  trash="$HOME/.Trash"
  if [[ -d "$trash" ]] && confirm "Esvaziar lixeira em $trash?"; then
    rm_glob "$trash" "*"
  else
    echo "Lixeira mantida."
  fi
fi

print_report "Espaço potencial liberado"
