#!/usr/bin/env bash
# Limpa caches de desenvolvimento gerais. Evita apagar codigo, configuracoes e dados de projetos.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-clean-lib.sh"

DEEP=0
WITH_DOCKER=0

usage() {
  cat <<'EOF'
Limpa caches de desenvolvimento gerais.

Opcoes:
  --yes          nao pede confirmacao
  --dry-run      mostra o que seria removido
  --deep         inclui caches maiores de ferramentas e stores de pacotes
  --with-docker  tambem roda limpeza Docker conservadora
  -h, --help     mostra esta ajuda

Exemplos:
  bash clean-dev-caches.sh --dry-run
  bash clean-dev-caches.sh --yes --deep
EOF
}

while [[ $# -gt 0 ]]; do
  if parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --deep) DEEP=1 ;;
    --with-docker) WITH_DOCKER=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

echo "== Limpeza de caches de desenvolvimento =="

echo "-- Homebrew"
rm_safe "$HOME/Library/Caches/Homebrew"
if command -v brew >/dev/null 2>&1; then
  run_cmd brew cleanup -s
fi

echo "-- Node.js"
if command -v npm >/dev/null 2>&1; then
  add_size "$HOME/.npm/_cacache"
  add_size "$HOME/.npm/_logs"
  run_cmd npm cache clean --force
else
  rm_safe "$HOME/.npm/_cacache"
  rm_safe "$HOME/.npm/_logs"
fi
rm_safe "$HOME/Library/Caches/Yarn"
if command -v yarn >/dev/null 2>&1; then run_cmd yarn cache clean; fi
if command -v pnpm >/dev/null 2>&1; then
  run_cmd pnpm store prune
else
  [[ $DEEP -eq 1 ]] && rm_safe "$HOME/.pnpm-store"
fi

echo "-- Python/Ruby"
rm_safe "$HOME/Library/Caches/pip"
rm_safe "$HOME/.cache/pip"
rm_safe "$HOME/.cache/pipenv"
rm_safe "$HOME/.cache/poetry"
[[ $DEEP -eq 1 ]] && rm_safe "$HOME/.bundle/cache"
[[ $DEEP -eq 1 ]] && rm_safe "$HOME/.gem/specs"

echo "-- Go/Rust"
if command -v go >/dev/null 2>&1; then
  run_cmd go clean -cache -testcache -modcache
else
  rm_safe "$HOME/Library/Caches/go-build"
  rm_safe "$HOME/.cache/go-build"
fi
rm_safe "$HOME/Library/Caches/Cargo"
rm_safe "$HOME/.cargo/registry/cache"
rm_safe "$HOME/.cargo/git/checkouts"

echo "-- IDEs e ferramentas"
rm_glob "$HOME/Library/Caches/JetBrains" "*"
rm_glob "$HOME/Library/Logs/JetBrains" "*"
rm_safe "$HOME/Library/Caches/com.microsoft.VSCode"
rm_safe "$HOME/Library/Application Support/Code/Cache"
rm_safe "$HOME/Library/Application Support/Code/CachedData"
rm_safe "$HOME/Library/Application Support/Code/Code Cache"
rm_safe "$HOME/Library/Application Support/Code/GPUCache"

if [[ $WITH_DOCKER -eq 1 ]]; then
  echo "-- Docker"
  if command -v docker >/dev/null 2>&1; then
    run_cmd docker system prune -f
    run_cmd docker builder prune -f
  else
    echo "Docker nao encontrado."
  fi
fi

print_report "Espaço potencial liberado"
