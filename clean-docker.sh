#!/usr/bin/env bash
# Limpa recursos Docker. Volumes exigem flag separada por poderem conter dados.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-clean-lib.sh"

VOLUMES=0
AGGRESSIVE=0

usage() {
  cat <<'EOF'
Limpa recursos Docker nao usados.

Opcoes:
  --yes          nao pede confirmacao
  --dry-run      mostra comandos que seriam executados
  --aggressive   remove tambem imagens nao usadas, nao apenas dangling
  --volumes      inclui volumes nao usados (pode apagar dados)
  -h, --help     mostra esta ajuda

Exemplos:
  bash clean-docker.sh --dry-run
  bash clean-docker.sh --yes --aggressive
EOF
}

while [[ $# -gt 0 ]]; do
  if parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --volumes) VOLUMES=1 ;;
    --aggressive) AGGRESSIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

echo "== Limpeza Docker =="
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker nao encontrado."
  exit 0
fi

echo "-- Uso atual"
run_cmd docker system df

echo "-- Limpeza"
run_cmd docker container prune -f
run_cmd docker network prune -f
run_cmd docker builder prune -f
if [[ $AGGRESSIVE -eq 1 ]]; then
  run_cmd docker image prune -a -f
else
  run_cmd docker image prune -f
fi

if [[ $VOLUMES -eq 1 ]]; then
  if confirm "Remover volumes Docker nao usados? Volumes podem conter bancos e dados locais."; then
    run_cmd docker volume prune -f
  else
    echo "Volumes mantidos."
  fi
fi

echo "-- Uso apos limpeza"
run_cmd docker system df
echo "Feito."
