#!/usr/bin/env bash
# Relatorio de uso de espaco no macOS. Nao apaga nada.

set -euo pipefail

LIMIT=25
ROOTS="$HOME/Downloads,$HOME/Desktop,$HOME/Documents,$HOME/Movies,$HOME/Pictures,$HOME/Library/Developer,$HOME/Library/Android,$HOME/Library/Application Support,$HOME/Library/Caches"

usage() {
  cat <<'EOF'
Mostra os maiores diretorios/arquivos para ajudar a decidir o que limpar.

Opcoes:
  --limit N       quantidade de itens por secao (padrao: 25)
  --roots PATHS   caminhos separados por virgula
  -h, --help      mostra esta ajuda

Exemplo:
  bash mac-space-report.sh --limit 30
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit=*) LIMIT="${1#*=}" ;;
    --limit)
      if [[ -n "${2-}" ]]; then LIMIT="$2"; shift; else echo "Faltou valor para --limit"; exit 2; fi
      ;;
    --roots=*) ROOTS="${1#*=}" ;;
    --roots)
      if [[ -n "${2-}" ]]; then ROOTS="$2"; shift; else echo "Faltou valor para --roots"; exit 2; fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

hr_du() {
  awk '
    function human(kb) {
      if (kb>=1073741824) return sprintf("%.1f TB", kb/1073741824)
      if (kb>=1048576) return sprintf("%.1f GB", kb/1048576)
      if (kb>=1024) return sprintf("%.1f MB", kb/1024)
      return sprintf("%d KB", kb)
    }
    { size=$1; $1=""; sub(/^ /,""); printf "%10s  %s\n", human(size), $0 }
  '
}

echo "== Uso de disco =="
df -h /

echo
echo "== Maiores itens por pasta =="
IFS=',' read -r -a ROOT_ARR <<< "$ROOTS"
for root in "${ROOT_ARR[@]}"; do
  [[ -d "$root" ]] || continue
  printf "\n-- %s\n" "$root"
  (find "$root" -mindepth 1 -maxdepth 1 -exec du -sk {} + 2>/dev/null || true) \
    | sort -nr \
    | head -n "$LIMIT" \
    | hr_du
done

echo
echo "== Backups iOS =="
backup_dir="$HOME/Library/Application Support/MobileSync/Backup"
if [[ -d "$backup_dir" ]]; then
  (find "$backup_dir" -mindepth 1 -maxdepth 1 -exec du -sk {} + 2>/dev/null || true) \
    | sort -nr \
    | head -n "$LIMIT" \
    | hr_du
else
  echo "Nenhum diretorio encontrado em $backup_dir"
fi
