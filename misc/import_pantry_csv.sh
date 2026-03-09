#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Import pantry CSV data into the Pantry API.

Usage:
  misc/import_pantry_csv.sh --csv /path/to/Vorraete.csv [options]

Options:
  --csv PATH           CSV file path (required)
  --api-base URL       API base URL (default: http://localhost:4000)
  --dry-run            Parse and print payloads without POSTing
  --no-header          Treat first row as data (default assumes header)
  -h, --help           Show this help

CSV format expected (semicolon-separated):
  ;Bezeichnung;Menge;Art;MHD;...

Menge supports units:
  g, kg, ml, l

Packaging mapping from Art:
  can:   dose, can
  box:   packung, karton, box
  bag:   tute/tuete/tuete, beutel, sack, bag
  jar:   glas, jar
  other: everything else
USAGE
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing dependency: $1" >&2
    exit 1
  fi
}

trim() {
  local s="$1"
  s="${s%$'\r'}"
  # shellcheck disable=SC2001
  s="$(echo "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  printf '%s' "$s"
}

slugify() {
  local s="$1"
  s="$(printf '%s' "$s" | iconv -f utf-8 -t ascii//translit 2>/dev/null || printf '%s' "$s")"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"
  if [[ -z "$s" ]]; then
    s="item"
  fi
  printf '%s' "$s"
}

parse_amount_unit() {
  local raw="$1"
  local clean amount raw_unit unit
  clean="$(printf '%s' "$raw" | tr ',' '.' | tr -d ' ')"

  if [[ "$clean" =~ ^([0-9]+(\.[0-9]+)?)(g|kg|ml|l)$ ]]; then
    amount="${BASH_REMATCH[1]}"
    raw_unit="${BASH_REMATCH[3]}"
  else
    return 1
  fi

  case "$raw_unit" in
    g)
      unit="grams"
      ;;
    kg)
      unit="grams"
      amount="$(awk "BEGIN { printf \"%.3f\", ${amount} * 1000 }")"
      ;;
    ml)
      unit="ml"
      ;;
    l)
      unit="l"
      ;;
    *)
      return 1
      ;;
  esac

  printf '%s\t%s' "$amount" "$unit"
}

map_packaging() {
  local art_lc="$1"

  case "$art_lc" in
    *dose*|*can*)
      printf 'can'
      ;;
    *packung*|*karton*|*box*)
      printf 'box'
      ;;
    *tüte*|*tuete*|*tute*|*beutel*|*sack*|*bag*)
      printf 'bag'
      ;;
    *glas*|*jar*)
      printf 'jar'
      ;;
    *)
      printf 'other'
      ;;
  esac
}

CSV_PATH=""
API_BASE="http://localhost:4000"
DRY_RUN=0
HAS_HEADER=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --csv)
      CSV_PATH="${2:-}"
      shift 2
      ;;
    --api-base)
      API_BASE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-header)
      HAS_HEADER=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CSV_PATH" ]]; then
  echo "--csv is required" >&2
  usage >&2
  exit 1
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "csv not found: $CSV_PATH" >&2
  exit 1
fi

require_cmd awk
require_cmd curl
require_cmd jq
require_cmd sed
require_cmd tr
require_cmd iconv
require_cmd awk

inserted=0
skipped=0
failed=0
processed=0

read_cmd=(cat "$CSV_PATH")
if [[ "$HAS_HEADER" -eq 1 ]]; then
  read_cmd=(tail -n +2 "$CSV_PATH")
fi

while IFS=';' read -r _ name menge art mhd _rest; do
  name="$(trim "$name")"
  menge="$(trim "$menge")"
  art="$(trim "$art")"
  mhd="$(trim "$mhd")"

  [[ -z "$name" ]] && continue
  processed=$((processed + 1))

  parsed="$(parse_amount_unit "$menge" || true)"
  if [[ -z "$parsed" ]]; then
    echo "skip row ${processed}: cannot parse Menge '${menge}'" >&2
    skipped=$((skipped + 1))
    continue
  fi

  amount="${parsed%%$'\t'*}"
  unit="${parsed##*$'\t'}"
  art_lc="$(printf '%s' "$art" | tr '[:upper:]' '[:lower:]')"
  packaging="$(map_packaging "$art_lc")"

  slug="$(slugify "$name")"
  picture_key="items/import/${slug}.png"

  payload="$(jq -n \
    --arg name "$name" \
    --arg best_before "$mhd" \
    --argjson content_amount "$amount" \
    --arg content_unit "$unit" \
    --arg packaging "$packaging" \
    --arg picture_key "$picture_key" \
    '{data:{type:"items",attributes:{name:$name,best_before:$best_before,content_amount:$content_amount,content_unit:$content_unit,packaging:$packaging,picture_key:$picture_key}}}')"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "$payload"
    inserted=$((inserted + 1))
    continue
  fi

  status="$(curl -s -o /tmp/pantry_import_response.json -w '%{http_code}' \
    -X POST "${API_BASE%/}/api/items" \
    -H 'content-type: application/vnd.api+json' \
    -d "$payload")"

  if [[ "$status" == "201" ]]; then
    inserted=$((inserted + 1))
  else
    failed=$((failed + 1))
    detail="$(jq -r '.errors[0].detail // .errors[0].title // "unknown"' /tmp/pantry_import_response.json 2>/dev/null || echo 'unknown')"
    echo "fail row ${processed} (${name}): HTTP ${status} - ${detail}" >&2
  fi
done < <("${read_cmd[@]}")

echo "import summary: inserted=${inserted} skipped=${skipped} failed=${failed} processed=${processed}"

if [[ "$failed" -gt 0 ]]; then
  exit 2
fi
