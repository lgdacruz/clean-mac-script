#!/usr/bin/env bash

ASK_CONFIRM=${ASK_CONFIRM:-1}
DRYRUN=${DRYRUN:-0}
DRY_LIST=()
bytes_freed=0

confirm() {
  if [[ $ASK_CONFIRM -eq 0 ]]; then return 0; fi
  read -r -p "$1 [y/N] " resp
  [[ "$resp" == "y" || "$resp" == "Y" ]]
}

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

run_rm() {
  local path="$1"
  if [[ -z "${path:-}" ]]; then
    printf "Bloqueado: caminho vazio\n"
    return 0
  fi
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

rm_safe() {
  local path="$1"
  add_size "$path"
  run_rm "$path"
}

rm_glob() {
  local dir="$1"
  local pattern="$2"
  if [[ ! -d "$dir" ]]; then
    printf "Ignorando (inexistente): %s\n" "$dir"
    return 0
  fi
  local item found=0
  if [[ "$pattern" == */* ]]; then
    while IFS= read -r -d '' item; do
      found=1
      rm_safe "$item"
    done < <(find "$dir" -path "$dir/$pattern" -print0 2>/dev/null)
  else
    while IFS= read -r -d '' item; do
      found=1
      rm_safe "$item"
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
  fi
  if [[ $found -eq 0 ]]; then
    printf "Ignorando (sem matches): %s/%s\n" "$dir" "$pattern"
    return 0
  fi
  return 0
}

rm_find_older_than() {
  local dir="$1"
  local days="$2"
  local mindepth="${3:-1}"
  if [[ ! -d "$dir" ]]; then
    printf "Ignorando (inexistente): %s\n" "$dir"
    return 0
  fi
  local item found=0
  while IFS= read -r -d '' item; do
    found=1
    rm_safe "$item"
  done < <(find "$dir" -mindepth "$mindepth" -maxdepth "$mindepth" -mtime +"$days" -print0 2>/dev/null)
  [[ $found -eq 0 ]] && printf "Ignorando (sem itens com mais de %s dias): %s\n" "$days" "$dir"
  return 0
}

run_cmd() {
  if [[ $DRYRUN -eq 1 ]]; then
    printf "[dry-run] %s\n" "$*"
  else
    "$@" >/dev/null 2>&1 || true
  fi
}

hr_value() {
  local b="$1"
  awk -v b="$b" 'BEGIN{
    if (b>=1099511627776) { printf("%.1f TB", b/1099511627776); exit }
    if (b>=1073741824) { printf("%.1f GB", b/1073741824); exit }
    if (b>=1048576) { printf("%.1f MB", b/1048576); exit }
    if (b>=1024) { printf("%.1f KB", b/1024); exit }
    printf("%d B", b)
  }'
}

highlight() {
  local text="$1"
  if [[ -t 1 ]]; then
    printf "\033[1;32m%s\033[0m\n" "$text"
  else
    printf "%s\n" "$text"
  fi
}

print_report() {
  local label="${1:-Espaço potencial liberado}"
  highlight "≈ ${label}: $(hr_value "$bytes_freed")"
  [[ $DRYRUN -eq 1 ]] && echo "Modo dry-run. Nada foi apagado."
  if [[ $DRYRUN -eq 1 && ${#DRY_LIST[@]} -gt 0 ]]; then
    printf "\nItens que seriam removidos (dry-run):\n"
    local p
    for p in "${DRY_LIST[@]}"; do printf " - %s\n" "$p"; done
  fi
}

parse_common_flag() {
  case "$1" in
    --yes) ASK_CONFIRM=0; return 0 ;;
    --dry-run) DRYRUN=1; return 0 ;;
    *) return 1 ;;
  esac
}
