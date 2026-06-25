#!/usr/bin/env bash
# clean-mobile-caches.sh
# Uso:
#   bash clean-mobile-caches.sh [opcoes]
# Opcoes principais:
#   --yes                nao pede confirmacao
#   --dry-run            mostra o que seria removido
#   --deep               inclui caches pesados (npm/yarn/pnpm/pods/wrapper)
#   --erase-ios-sims     apaga dados de todos os simuladores iOS
#   --delete-avds        apaga todos os AVDs em ~/.android/avd
#   --delete-xcode-archives apaga archives exportados do Xcode
#   --delete-device-support apaga suportes de devices iOS baixados pelo Xcode
#   --projects PATHS     limpa android/ de outros projetos (ex: \"dir1,dir2\")
#   --empty-trash        esvazia lixeira do mac (~/ .Trash)
#   -h, --help           mostra esta ajuda

set -euo pipefail

ASK_CONFIRM=1
ERASE_IOS_SIMS=0
DELETE_AVDS=0
DELETE_XCODE_ARCHIVES=0
DELETE_DEVICE_SUPPORT=0
EMPTY_TRASH=0
DEEP=0
DRYRUN=0
PROJECTS=""
DRY_LIST=()

usage() {
  cat <<'EOF'
Limpa caches de build iOS/Android/Metro em macOS.

Opcoes:
  --yes                nao pede confirmacao
  --dry-run            mostra o que seria removido
  --empty-trash        esvazia lixeira do mac (~/ .Trash)
  --deep               inclui caches pesados (npm/yarn/pnpm/pods/wrapper)
  --erase-ios-sims     apaga dados de todos os simuladores iOS
  --delete-avds        apaga todos os AVDs em ~/.android/avd
  --delete-xcode-archives apaga archives exportados do Xcode (nao e cache)
  --delete-device-support apaga suportes de devices iOS baixados pelo Xcode
  --projects PATHS     caminhos separados por virgula para limpar android/
  -h, --help           mostra esta ajuda
Exemplos:
  bash clean-mobile-caches.sh --dry-run
  bash clean-mobile-caches.sh --yes --deep --erase-ios-sims --delete-avds
  bash clean-mobile-caches.sh --dry-run --deep --delete-xcode-archives
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASK_CONFIRM=0 ;;
    --erase-ios-sims) ERASE_IOS_SIMS=1 ;;
    --delete-avds) DELETE_AVDS=1 ;;
    --delete-xcode-archives) DELETE_XCODE_ARCHIVES=1 ;;
    --delete-device-support) DELETE_DEVICE_SUPPORT=1 ;;
    --empty-trash) EMPTY_TRASH=1 ;;
    --deep) DEEP=1 ;;
    --dry-run) DRYRUN=1 ;;
    --projects=*) PROJECTS="${1#*=}" ;;
    --projects)
      if [[ -n "${2-}" ]]; then PROJECTS="$2"; shift; else echo "Faltou valor para --projects"; exit 2; fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Flag desconhecida: $1"; usage; exit 2 ;;
  esac
  shift
done

confirm() {
  if [[ $ASK_CONFIRM -eq 0 ]]; then return 0; fi
  read -r -p "$1 [y/N] " resp
  [[ "$resp" == "y" || "$resp" == "Y" ]]
}

DRY_LIST=()

run_rm() {
  local path="$1"
  if [[ -z "${path:-}" ]]; then
    printf "Bloqueado: caminho vazio\n"
    return 0
  fi
  path="$(printf "%s" "$path")"
  [[ "$path" == "/" || "$path" == "$HOME" ]] && { printf "Bloqueado: %s\n" "$path"; return 0; }
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ $DRYRUN -eq 1 ]]; then
      printf "[dry-run] rm -rf %s\n" "$path"
      DRY_LIST+=("$path")
    else
      printf "Removendo %s\n" "$path"
      if ! rm -rf -- "$path"; then
        printf "Aviso: nao foi possivel remover completamente: %s\n" "$path"
        printf "       Feche apps que possam estar usando esse cache e rode novamente.\n"
        return 0
      fi
    fi
  else
    printf "Ignorando (inexistente): %s\n" "$path"
  fi
}

bytes_freed=0
# more robust size calculation (handles missing du output)
add_size() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local sz_kb
    sz_kb=$(du -sk "$path" 2>/dev/null | awk '{print $1}' || true)
    if [[ -n "$sz_kb" && "$sz_kb" =~ ^[0-9]+$ ]]; then
      bytes_freed=$((bytes_freed + (sz_kb * 1024)))
    fi
  fi
}

rm_safe() {
  local path="$1"
  add_size "$path"
  run_rm "$path"
}

rm_glob() {
  local dir="$1"
  local pattern="$2"
  shopt -s nullglob
  local matches=("$dir"/$pattern)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 0 ]]; then
    printf "Ignorando (sem matches): %s/%s\n" "$dir" "$pattern"
    return 0
  fi
  local item
  for item in "${matches[@]}"; do
    rm_safe "$item"
  done
}

run_cmd() {
  if [[ $DRYRUN -eq 1 ]]; then
    printf "[dry-run] %s\n" "$*"
  else
    "$@" >/dev/null 2>&1 || true
  fi
}

# try to use numfmt for nicer formatting if available, fallback to awk
hr() {
  local b="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --format="%.0f" "$b"
  else
    awk -v b="$b" 'BEGIN{
      if (b>=1073741824) v=b/1073741824;
      else if (b>=1048576) v=b/1048576;
      else v=b/1024;
      printf("%.0f\n", v);
    }'
  fi
}

unit() {
  local b="$1"
  if command -v numfmt >/dev/null 2>&1; then
    # numfmt's --to=iec gives suffix; map to GB/MB/KB
    if (( b >= 1073741824 )); then echo "GB"
    elif (( b >= 1048576 )); then echo "MB"
    else echo "KB"; fi
  else
    awk -v b="$b" 'BEGIN{
      if (b>=1073741824) print "GB";
      else if (b>=1048576) print "MB";
      else print "KB";
    }'
  fi
}

highlight() {
  local text="$1"
  if [[ -t 1 ]]; then
    printf "\033[1;32m%s\033[0m\n" "$text"
  else
    printf "%s\n" "$text"
  fi
}

# esvazia lixeira do mac; protege se nao for macOS ou se estiver vazia
empty_trash() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "Lixeira: ignorado (requer macOS)."
    return
  fi
  local trash="$HOME/.Trash"
  if [[ ! -d "$trash" ]]; then
    echo "Lixeira: pasta nao encontrada em $trash"
    return
  fi
  echo "-- Lixeira"
  shopt -s nullglob dotglob
  local items=("$trash"/*)
  shopt -u nullglob dotglob
  if [[ ${#items[@]} -eq 0 ]]; then
    echo "Lixeira ja vazia."
    return
  fi
  if confirm "Esvaziar lixeira em $trash?"; then
    for f in "${items[@]}"; do rm_safe "$f"; done
  else
    echo "Lixeira mantida."
  fi
}

trap_on_exit() {
  local code=$?
  if [[ $DRYRUN -eq 1 && ${#DRY_LIST[@]} -gt 0 ]]; then
    printf "\nItens que seriam removidos (dry-run):\n"
    for p in "${DRY_LIST[@]}"; do printf " - %s\n" "$p"; done
  fi
  exit $code
}
trap trap_on_exit EXIT INT TERM

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Aviso: script pensado para macOS; prosseguindo assim mesmo."
fi

echo "== Limpeza de builds e caches iOS/Android =="

# 0) Encerrar simuladores/emuladores
if command -v xcrun >/dev/null 2>&1; then run_cmd osascript -e 'tell application "Simulator" to quit'; fi
if command -v adb >/dev/null 2>&1; then run_cmd adb emu kill; fi
run_cmd pkill -f qemu-system

# 1) iOS/Xcode
if [[ "$(uname)" == "Darwin" ]]; then
  echo "-- iOS/Xcode"
  rm_safe "$HOME/Library/Developer/Xcode/DerivedData"
  rm_safe "$HOME/Library/Developer/Xcode/iOS Device Logs"
  rm_safe "$HOME/Library/Developer/Xcode/UserData/Previews/Simulator Devices"
  rm_safe "$HOME/Library/Developer/Xcode/Products"
  rm_safe "$HOME/Library/Developer/Xcode/DocumentationCache"
  rm_safe "$HOME/Library/Caches/com.apple.dt.Xcode"
  rm_safe "$HOME/Library/Caches/org.swift.swiftpm"
  rm_safe "$HOME/Library/Developer/CoreSimulator/Caches"
  rm_safe "$HOME/Library/Logs/CoreSimulator"
  if command -v xcrun >/dev/null 2>&1; then
    run_cmd xcrun simctl delete unavailable
  fi
  if [[ $DEEP -eq 1 ]]; then
    rm_safe "$HOME/.swiftpm/cache"
    rm_safe "$HOME/.cache/org.swift.swiftpm"
  fi
  if [[ $DELETE_DEVICE_SUPPORT -eq 1 ]]; then
    if confirm "Apagar iOS DeviceSupport baixado pelo Xcode?"; then
      rm_safe "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
    fi
  fi
  if [[ $DELETE_XCODE_ARCHIVES -eq 1 ]]; then
    if confirm "Apagar Xcode Archives? Isso pode remover .xcarchive usados para reexportar apps."; then
      rm_safe "$HOME/Library/Developer/Xcode/Archives"
    fi
  fi
  if [[ $ERASE_IOS_SIMS -eq 1 ]] && command -v xcrun >/dev/null 2>&1; then
    if confirm "Apagar TODOS os dados dos simuladores iOS?"; then
      run_cmd xcrun simctl erase all
    fi
  fi
fi

# 2) Android/Gradle
echo "-- Android/Gradle"
clean_project_android() {
  local proj="$1"
  if [[ ! -d "$proj/android" ]]; then
    printf "Ignorando (sem android/): %s\n" "$proj"
    return
  fi
  printf ">> Projeto Android: %s\n" "$proj"
  pushd "$proj/android" >/dev/null
  if [[ $DRYRUN -eq 1 ]]; then
    echo "[dry-run] ./gradlew --stop && ./gradlew clean"
  else
    ./gradlew --stop >/dev/null 2>&1 || true
    ./gradlew clean >/dev/null 2>&1 || true
  fi
  popd >/dev/null
  rm_safe "$proj/android/.gradle"
  rm_safe "$proj/android/build"
  rm_safe "$proj/android/app/build"
}

# projeto atual
clean_project_android "$(pwd)"

# projetos adicionais
IFS=',' read -r -a PROJ_ARR <<< "${PROJECTS}"
for p in "${PROJ_ARR[@]:-}"; do
  [[ -z "${p// }" ]] && continue
  clean_project_android "$(cd "$p" 2>/dev/null && pwd || echo "$p")"
done

# Gradle global
rm_safe "$HOME/.gradle/caches"
rm_safe "$HOME/.gradle/daemon"
rm_safe "$HOME/.gradle/native"
rm_safe "$HOME/.gradle/build-cache"
if [[ $DEEP -eq 1 ]]; then
  rm_safe "$HOME/.gradle/wrapper/dists"
fi
# Android caches antigos
rm_safe "$HOME/.android/cache"
rm_safe "$HOME/.android/build-cache"
if [[ "$(uname)" == "Darwin" ]]; then
  rm_glob "$HOME/Library/Caches/Google" "AndroidStudio*"
  rm_glob "$HOME/Library/Logs/Google" "AndroidStudio*"
fi

# 3) Metro / Watchman
echo "-- Metro/Watchman"
if command -v watchman >/dev/null 2>&1; then
  run_cmd watchman watch-del-all
fi
rm_glob "${TMPDIR:-/tmp}" "metro-*"
rm_glob "${TMPDIR:-/tmp}" "react-*"
rm_glob "${TMPDIR:-/tmp}" "haste-map-*"
rm_safe "$HOME/Library/Metro"

# 4) AVDs
if [[ $DELETE_AVDS -eq 1 ]]; then
  if confirm "Remover TODOS os AVDs em ~/.android/avd?"; then
    rm_safe "$HOME/.android/avd"
  fi
fi

# 5) Package managers e CocoaPods
if [[ $DEEP -eq 1 ]]; then
  echo "-- Caches de package managers"
  # npm
  if command -v npm >/dev/null 2>&1; then
    add_size "$HOME/.npm/_cacache"
    add_size "$HOME/.npm/_logs"
    run_cmd npm cache clean --force
  else
    rm_safe "$HOME/.npm/_cacache"
    rm_safe "$HOME/.npm/_logs"
  fi
  # yarn
  rm_safe "$HOME/Library/Caches/Yarn"
  if command -v yarn >/dev/null 2>&1; then
    run_cmd yarn cache clean
  fi
  # pnpm
  if command -v pnpm >/dev/null 2>&1; then
    run_cmd pnpm store prune
  else
    rm_safe "$HOME/.pnpm-store"
  fi
  # CocoaPods
  rm_safe "$HOME/Library/Caches/CocoaPods"
  rm_safe "$HOME/.cocoapods/repos"
  if command -v pod >/dev/null 2>&1; then
    run_cmd pod cache clean --all
  fi
  # Flutter/Dart
  rm_safe "$HOME/.pub-cache/_temp"
  rm_safe "$HOME/.dartServer"
fi

# 6) Lixeira (opcional)
if [[ $EMPTY_TRASH -eq 1 ]]; then
  empty_trash
fi

# 7) Relatório
sz=$(hr "$bytes_freed"); u=$(unit "$bytes_freed")
if [[ $DRYRUN -eq 1 ]]; then
  highlight "≈ Espaço potencial liberado: ${sz} ${u}"
else
  echo "≈ Espaço potencial liberado: ${sz} ${u}"
fi
[[ $DRYRUN -eq 1 ]] && echo "Modo dry-run. Nada foi apagado."
echo "Feito."
