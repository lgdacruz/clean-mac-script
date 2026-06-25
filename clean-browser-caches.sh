#!/usr/bin/env bash
# Limpa caches de navegadores sem apagar perfis, cookies, historico ou extensoes.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-clean-lib.sh"

CLOSE_APPS=0

usage() {
  cat <<'EOF'
Limpa caches de navegadores sem apagar perfis/cookies/sessoes.

Opcoes:
  --yes          nao pede confirmacao
  --dry-run      mostra o que seria removido
  --close-apps   tenta fechar navegadores antes de limpar
  -h, --help     mostra esta ajuda

Exemplo:
  bash clean-browser-caches.sh --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
  if parse_common_flag "$1"; then shift; continue; fi
  case "$1" in
    --close-apps) CLOSE_APPS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

echo "== Limpeza de caches de navegadores =="

clean_chromium_profile_caches() {
  local root="$1"
  if [[ ! -d "$root" ]]; then
    printf "Ignorando (inexistente): %s\n" "$root"
    return 0
  fi
  local profile found=0
  shopt -s nullglob
  for profile in "$root"/Default "$root"/Profile\ * "$root"/Guest\ Profile "$root"/System\ Profile; do
    [[ -d "$profile" ]] || continue
    found=1
    rm_safe "$profile/Cache"
    rm_safe "$profile/Code Cache"
    rm_safe "$profile/GPUCache"
    rm_safe "$profile/Service Worker/CacheStorage"
  done
  shopt -u nullglob
  [[ $found -eq 0 ]] && printf "Ignorando (sem perfis): %s\n" "$root"
  return 0
}

if [[ $CLOSE_APPS -eq 1 ]]; then
  run_cmd osascript -e 'tell application "Google Chrome" to quit'
  run_cmd osascript -e 'tell application "Microsoft Edge" to quit'
  run_cmd osascript -e 'tell application "Firefox" to quit'
  run_cmd osascript -e 'tell application "Safari" to quit'
fi

echo "-- Chrome"
rm_safe "$HOME/Library/Caches/Google/Chrome"
clean_chromium_profile_caches "$HOME/Library/Application Support/Google/Chrome"

echo "-- Microsoft Edge"
rm_safe "$HOME/Library/Caches/Microsoft Edge"
clean_chromium_profile_caches "$HOME/Library/Application Support/Microsoft Edge"

echo "-- Firefox"
rm_safe "$HOME/Library/Caches/Firefox"
rm_glob "$HOME/Library/Caches/Mozilla/Firefox/Profiles" "*/cache2"
rm_glob "$HOME/Library/Caches/Mozilla/Firefox/Profiles" "*/startupCache"

echo "-- Safari"
rm_safe "$HOME/Library/Caches/com.apple.Safari"
rm_safe "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches"

print_report "Espaço potencial liberado"
