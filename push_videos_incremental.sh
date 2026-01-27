#!/usr/bin/env bash
# push_videos_incremental.sh
# Detecta .mp4/.webm en astro-app (ignora node_modules) y sube los vídeos
# uno por uno en commits/pushes incrementales. Si un push falla, revierte
# el commit y continúa con el siguiente archivo.
#
# Uso:
#   ./push_videos_incremental.sh
#
# Variables configurables (export antes de ejecutar o editar aquí):
#   REPO_DIR     - directorio del repositorio (default = current dir)
#   REMOTE       - git remote a usar (default = origin)
#   BRANCH       - branch remoto al que hacer push (default = main)
#   PUSH_TIMEOUT - segundos máximo a esperar por cada push (default = 300)
#   RETRIES      - número de reintentos por push antes de marcar como error (default = 2)
#   DRY_RUN      - si se establece a "1", no hará commits ni pushes (para prueba)
#
# Requisitos:
#  - git disponible
#  - comando `timeout` (coreutils). Si no está, el script intentará continuar pero sin timeout.
#  - Ejecutar desde la raíz del repo o definir REPO_DIR.

set -u
IFS=$'\n\t'

# ---- Config ----
REPO_DIR="${REPO_DIR:-$(pwd)}"
REMOTE="${REMOTE:-origin}"
BRANCH="${BRANCH:-main}"
PUSH_TIMEOUT="${PUSH_TIMEOUT:-300}"   # seconds
RETRIES="${RETRIES:-2}"
DRY_RUN="${DRY_RUN:-0}"               # 1 = dry run, don't actually commit/push
LOGDIR="${LOGDIR:-${REPO_DIR}/.video_push_logs}"
SKIP_FILE="${SKIP_FILE:-${LOGDIR}/skipped_videos.txt}"
SUCCESS_LOG="${LOGDIR}/success.log"
ERROR_LOG="${LOGDIR}/error.log"

# ---- Helpers ----
info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
err()  { printf '%s\n' "[ERROR] $*" >&2; }

# Check repo
cd "$REPO_DIR" || { err "Cannot cd to $REPO_DIR"; exit 1; }
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "Not a git repository: $REPO_DIR"
  exit 1
fi

# Prepare logs dir
mkdir -p "$LOGDIR"
: > "$SUCCESS_LOG"
: > "$ERROR_LOG"
: > "$SKIP_FILE"

# Check timeout
TIMEOUT_CMD="timeout"
if ! command -v "$TIMEOUT_CMD" >/dev/null 2>&1; then
  warn "'timeout' not found in PATH; pushes will not be time-limited."
  TIMEOUT_CMD=""
fi

# Save starting branch
START_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
START_COMMIT="$(git rev-parse --verify HEAD)"

info "Repository: $REPO_DIR"
info "Remote: $REMOTE"
info "Branch: $BRANCH"
info "Starting branch: $START_BRANCH"
info "Push timeout: ${PUSH_TIMEOUT}s (use \$PUSH_TIMEOUT to change)"
if [ "$DRY_RUN" = "1" ]; then
  info "DRY RUN mode enabled — no commits or pushes will be executed."
fi

# ---- Find video files (.mp4, .webm), ignoring node_modules ----
info "Detecting .mp4 and .webm files under 'astro-app' (ignoring node_modules)..."
# Use a portable null-delimited find + read loop (works on macOS bash 3.x)
VIDEO_FILES=()
while IFS= read -r -d '' f; do
  VIDEO_FILES+=("$f")
done < <(find astro-app -type f \( -iname '*.mp4' -o -iname '*.webm' \) -not -path '*/node_modules/*' -not -path '*/dist/*' -not -path '*/backup_*/*' -not -path '*/backup*/*' -print0)

if [ "${#VIDEO_FILES[@]}" -eq 0 ]; then
  info "No .mp4/.webm files found under astro-app."
  exit 0
fi

# Sort list by size descending and present human-readable sizes
info "Found ${#VIDEO_FILES[@]} video files; listing by size (largest first):"
# use a temporary file for sorts
TMPLIST="$(mktemp)"
for f in "${VIDEO_FILES[@]}"; do
  # guard against spaces/newlines
  # use portable du: on macOS du -b is not available; use -k then multiply
  if du -b "$f" >/dev/null 2>&1; then
    size=$(du -b "$f" | awk '{print $1}')
  else
    # fallback: use du -k (kilobytes) then convert to bytes
    k=$(du -k "$f" | awk '{print $1}')
    size=$((k * 1024))
  fi
# finish for-loop
  printf "%s\t%s\n" "$size" "$f" >> "$TMPLIST"
done

# sort numerically by size (newline-delimited)
sort -nr "$TMPLIST" > "${TMPLIST}.sorted"

# print human readable sizes and rebuild VIDEO_FILES in order
VIDEO_FILES=()
while IFS=$'\t' read -r size file; do
  # try numfmt if available
  if command -v numfmt >/dev/null 2>&1; then
    human=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
  else
    human="${size}B"
  fi
  printf "    %s  %s\n" "$human" "$file"
  VIDEO_FILES+=("$file")
done < "${TMPLIST}.sorted"
rm -f "$TMPLIST" "${TMPLIST}.sorted"
# ---- Process files one-by-one ----
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIPPED_COUNT=0

for file in "${VIDEO_FILES[@]}"; do
  # Skip if already in skip file
  if grep -Fxq "$file" "$SKIP_FILE"; then
    info "Skipping previously-skipped file: $file"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  fi

  info "Processing: $file"
  commit_msg="chore(video): add ${file}"

  if [ "$DRY_RUN" = "1" ]; then
    info "[DRY RUN] git add \"$file\""
    info "[DRY RUN] git commit -m \"$commit_msg\""
    info "[DRY RUN] git push $REMOTE $BRANCH"
    continue
  fi

  # Add file to index
  if ! git add -- "$file"; then
    warn "git add failed for $file — skipping"
    echo "$file  git add failed" >> "$ERROR_LOG"
    echo "$file" >> "$SKIP_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Commit
  if ! git commit -m "$commit_msg" --no-verify; then
    warn "git commit failed for $file — un-staging and skipping"
    git reset --mixed HEAD -- || true
    git restore --staged -- "$file" 2>/dev/null || true
    echo "$file  git commit failed" >> "$ERROR_LOG"
    echo "$file" >> "$SKIP_FILE"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Attempt push with retries and timeout
  attempt=0
  pushed=0
  last_err=""
  while [ $attempt -le "$RETRIES" ]; do
    attempt=$((attempt + 1))
    info "Pushing (attempt ${attempt}/${RETRIES})..."
    if [ -n "$TIMEOUT_CMD" ]; then
      if timeout "$PUSH_TIMEOUT" git push "$REMOTE" "HEAD:$BRANCH"; then
        pushed=1
        break
      else
        last_err="git push failed or timed out (attempt $attempt)"
      fi
    else
      if git push "$REMOTE" "HEAD:$BRANCH"; then
        pushed=1
        break
      else
        last_err="git push failed (attempt $attempt)"
      fi
    fi
    # wait a little between retries
    sleep 3
  done

  if [ "$pushed" -eq 1 ]; then
    info "Push succeeded for $file"
    echo "$(date --iso-8601=seconds)  SUCCESS  $file" >> "$SUCCESS_LOG"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    # continue to next file
    continue
  fi

  # Push failed after retries → revert the commit and unstage the file
  warn "Push failed for $file after $RETRIES attempts: $last_err"
  echo "$(date --iso-8601=seconds)  FAILED  $file  ($last_err)" >> "$ERROR_LOG"
  FAIL_COUNT=$((FAIL_COUNT + 1))

  # Undo last commit (the one we just made), keep working tree unchanged
  # Use mixed reset to remove commit and unstage
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git reset --mixed HEAD~1 --quiet || {
      warn "git reset failed; you may need to manually remove the commit for $file"
    }
  fi

  # Remove the file from index if it got staged somehow
  git restore --staged -- "$file" 2>/dev/null || true

  # Add to skip list so we don't try again
  echo "$file" >> "$SKIP_FILE"
  info "Added to skip list: $file"

  # continue to next file
done

# ---- Summary ----
info "Done."
info "Successful pushes: $SUCCESS_COUNT"
info "Failed (skipped after errors): $FAIL_COUNT"
info "Previously skipped or unchanged: $SKIPPED_COUNT"
info "Logs:"
info "  Success log: $SUCCESS_LOG"
info "  Error log:   $ERROR_LOG"
info "  Skip list:   $SKIP_FILE"

# End script
