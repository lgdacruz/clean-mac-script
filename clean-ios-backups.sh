#!/usr/bin/env bash
# Lista e remove backups iOS locais. Nao apaga automaticamente sem flag explicita.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-clean-lib.sh"

DELETE_OLDER_THAN=""
DELETE_ALL=0
BACKUP_DIR="$HOME/Library/Application Support/MobileSync/Backup"

usage() {
  cat <<'EOF'
Lista e remove backups locais de iPhone/iPad.

Opcoes:
  --yes                  nao pede confirmacao
  --dry-run              mostra o que seria removido
  --delete-older-than N   apaga backups com mais de N dias
  --delete-all            apaga todos os backups locais
  -h, --help              mostra esta ajuda

Exemplos:
  bash clean-ios-backups.sh
  bash clean-ios-backups.sh --dry-run --delete-older-than 90
EOF
}

while [[ $# -gt 0 ]]; do
  if parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --delete-older-than=*) DELETE_OLDER_THAN="${1#*=}" ;;
    --delete-older-than)
      if [[ -n "${2-}" ]]; then DELETE_OLDER_THAN="$2"; shift; else echo "Faltou valor para --delete-older-than"; exit 2; fi
      ;;
    --delete-all) DELETE_ALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

echo "== Backups iOS locais =="
if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Nenhum diretorio encontrado em $BACKUP_DIR"
  exit 0
fi

echo "-- Backups encontrados"
find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null \
  | xargs -0 du -sk 2>/dev/null \
  | sort -nr \
  | awk '{
      size=$1; $1=""; sub(/^ /,"");
      if (size>=1048576) printf "%.1f GB  %s\n", size/1048576, $0;
      else if (size>=1024) printf "%.1f MB  %s\n", size/1024, $0;
      else printf "%d KB  %s\n", size, $0;
    }'

if [[ $DELETE_ALL -eq 1 ]]; then
  if confirm "Apagar TODOS os backups iOS locais?"; then
    rm_glob "$BACKUP_DIR" "*"
  else
    echo "Backups mantidos."
  fi
elif [[ -n "$DELETE_OLDER_THAN" ]]; then
  if ! [[ "$DELETE_OLDER_THAN" =~ ^[0-9]+$ ]] || [[ "$DELETE_OLDER_THAN" -lt 1 ]]; then
    echo "--delete-older-than precisa ser um numero positivo."
    exit 2
  fi
  if confirm "Apagar backups iOS com mais de $DELETE_OLDER_THAN dias?"; then
    rm_find_older_than "$BACKUP_DIR" "$DELETE_OLDER_THAN" 1
  else
    echo "Backups mantidos."
  fi
else
  echo
  echo "Nada foi apagado. Use --delete-older-than N ou --delete-all para remover backups."
fi

print_report "Espaço potencial liberado"
