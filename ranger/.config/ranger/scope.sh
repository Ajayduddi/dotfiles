#!/usr/bin/env bash
# Ranger preview script with pixel previews for Kitty/WezTerm and fallbacks to chafa.
# - Kitty/WezTerm: pixel-accurate previews (inside tmux too, with allow-passthrough)
# - Elsewhere: character previews via chafa
# Supports: images, videos (1 frame), PDFs (first page), text, and generic metadata

set -uo pipefail

FILE_PATH="$1"
PREVIEW_WIDTH="${2:-80}"     # in terminal cells
PREVIEW_HEIGHT="${3:-40}"    # in terminal cells

exists() { command -v "$1" >/dev/null 2>&1; }

previews_supported() {
  # Only allow pixel-capable paths; otherwise let ranger fall back to defaults
  if is_kitty_term || is_wezterm || supports_sixel; then
    return 0
  fi
  return 1
}

# Terminal detection
is_kitty_term() {
  [[ -n "${KITTY_WINDOW_ID:-}" ]] || [[ "${TERM:-}" == xterm-kitty* ]]
}

is_wezterm() {
  # Only true when actually running inside WezTerm
  [[ -n "${WEZTERM_EXECUTABLE:-}" ]] || [[ "${TERM_PROGRAM:-}" == "WezTerm" ]]
}

supports_sixel() {
  # Enable if TERM advertises sixel or user forces via RANGER_SIXEL=1
  [[ "${TERM:-}" == *sixel* ]] || [[ "${RANGER_SIXEL:-0}" == 1 ]]
}

# Try picture-perfect previews first
kitty_place() {
  # Place image into the preview pane area using cell geometry
  local geom="${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}@0x0"
  kitty +kitten icat --silent --transfer-mode=memory --place="$geom" --align=left --scale-up -- "$1" 2>/dev/null
}

wezterm_place() {
  # WezTerm's imgcat scales to fit; constrain by cells if supported
  if wezterm imgcat --help 2>/dev/null | grep -q -- '--width'; then
    wezterm imgcat --width "${PREVIEW_WIDTH}" --height "${PREVIEW_HEIGHT}" -- "$1" 2>/dev/null
  else
    wezterm imgcat -- "$1" 2>/dev/null
  fi
}

# chafa renderer for broad compatibility
chafa_render() {
  local fmt="symbols"
  if supports_sixel && chafa --help 2>/dev/null | grep -q -- '--format=sixels'; then
    fmt="sixels"
  fi
  chafa --view-size="${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}" \
        --stretch \
        --animate=off \
        --format="$fmt" \
        --clear -- - 2>/dev/null
}

# MIME type
MIMETYPE=$(file --mime-type -Lb -- "$FILE_PATH" 2>/dev/null || echo application/octet-stream)

# Helpers to show via pixel protocol when possible
show_pixel_image() {
  local img="$1"
  # Prefer Kitty protocol if kitty session or kitty is available
  if is_kitty_term && exists kitty; then
    # Clear any prior images in the pane (ignore errors)
    kitty +kitten icat --silent --clear 2>/dev/null || true
    kitty_place "$img" && return 0
  fi
  # Try WezTerm next
  if is_wezterm && exists wezterm; then
    wezterm_place "$img" && return 0
  fi
  return 1
}

make_tmp_png() {
  mktemp --suffix=.png 2>/dev/null || mktemp /tmp/ranger-preview-XXXXXX.png
}

case "$MIMETYPE" in
  image/*)
    if show_pixel_image "$FILE_PATH"; then exit 0; fi
    if exists chafa; then cat -- "$FILE_PATH" | chafa_render && exit 0; fi
    ;;

  video/*)
    # Extract one frame then show
    if exists ffmpeg; then
      tmp_png=$(make_tmp_png)
      if ffmpeg -loglevel error -ss 1 -i "$FILE_PATH" -frames:v 1 -f image2 "$tmp_png" 2>/dev/null; then
        if show_pixel_image "$tmp_png"; then rm -f "$tmp_png"; exit 0; fi
        if exists chafa; then cat -- "$tmp_png" | chafa_render && rm -f "$tmp_png" && exit 0; fi
      fi
      rm -f "$tmp_png" 2>/dev/null || true
    fi
    ;;

  application/pdf)
    # Render first page as PNG then show
    if exists pdftoppm; then
      tmp_png=$(make_tmp_png)
      if pdftoppm -f 1 -l 1 -scale-to-x 1024 -scale-to-y -1 -singlefile -png -- "$FILE_PATH" "${tmp_png%.png}" 2>/dev/null; then
        if show_pixel_image "$tmp_png"; then rm -f "$tmp_png"; exit 0; fi
        if exists chafa; then cat -- "$tmp_png" | chafa_render && rm -f "$tmp_png" && exit 0; fi
      fi
      rm -f "$tmp_png" 2>/dev/null || true
    fi
    if exists pdftotext; then pdftotext -l 5 -nopgbrk -- "$FILE_PATH" - 2>/dev/null | sed -n '1,200p' && exit 0; fi
    ;;

  text/*|application/json|application/xml)
    sed -n '1,200p' -- "$FILE_PATH" && exit 0
    ;;

  *) ;;
esac

# Fallbacks: metadata then hex
if exists exiftool; then exiftool -- "$FILE_PATH" | sed -n '1,200p' && exit 0; fi
if exists mediainfo; then mediainfo -- "$FILE_PATH" | sed -n '1,200p' && exit 0; fi

xxd -g 1 -l 2048 -- "$FILE_PATH" 2>/dev/null || head -c 2048 -- "$FILE_PATH" 2>/dev/null || printf 'No preview available.'
exit 0