#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║          scrapper_rapper  —  website spider & extractor          ║
# ║          spidering · js hunting · file extraction · recon        ║
# ╚══════════════════════════════════════════════════════════════════╝
# Usage: scrapper_rapper.sh -u <url> [options]

set -euo pipefail

# ─── colors ─────────────────────────────────────────────────────────
R=$'\033[0;31m' G=$'\033[0;32m' Y=$'\033[0;33m' B=$'\033[0;34m'
C=$'\033[0;36m' M=$'\033[0;35m' W=$'\033[1;37m' DIM=$'\033[2m' N=$'\033[0m'
BOLD=$'\033[1m'

# ════════════════════════════════════════════════════════════════════
#  DEFAULTS
# ════════════════════════════════════════════════════════════════════

# ── core ────────────────────────────────────────────────────────────
TARGET=""
OUTPUT_DIR=""
VERBOSITY=1

# ── spider ──────────────────────────────────────────────────────────
DEPTH=3
THREADS=10
MAX_PAGES=0                  # 0 = unlimited
DELAY=0                      # seconds between requests

# ── network ─────────────────────────────────────────────────────────
TIMEOUT=15
RETRIES=2
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36"
PROXY=""
COOKIES=""
EXTRA_HEADERS=()
FOLLOW_REDIRECTS=true
RATE=0                       # max req/sec  (0 = unlimited)

# ── auth ────────────────────────────────────────────────────────────
BASIC_AUTH=""                # user:pass
BEARER_TOKEN=""

# ── scope ───────────────────────────────────────────────────────────
SUBDOMAINS=false
EXTERNAL=false
EXCLUDE_PATTERN=""
INCLUDE_PATTERN=""
RESPECT_ROBOTS=false

# ── extraction flags ────────────────────────────────────────────────
EXTRACT_JS=true
EXTRACT_CSS=true
EXTRACT_DOCS=true
EXTRACT_IMAGES=true
EXTRACT_EMAILS=false
EXTRACT_SECRETS=false
EXTRACT_ENDPOINTS=false
EXTRACT_FORMS=false
EXTRACT_COMMENTS=false
EXTRACT_PARAMS=false
DOWNLOAD_JS=false
DOWNLOAD_CSS=false

# ── passive sources ─────────────────────────────────────────────────
USE_WAYBACK=false
USE_GAU=false
USE_KATANA=false
USE_GOSPIDER=false
USE_HAKRAWLER=false
USE_SUBFINDER=false

# ── output ──────────────────────────────────────────────────────────
JSON_OUTPUT=false
NO_COLOR=false
SILENT=false
SAVE_HTML=false
APPEND=false

# ════════════════════════════════════════════════════════════════════
#  LOGGING
# ════════════════════════════════════════════════════════════════════
_c() { $NO_COLOR && echo -ne "$2" || echo -ne "$1$2$N"; }

log()   { $SILENT || { [[ $VERBOSITY -ge 1 ]] && echo -e "$(_c "$W" '[*]') $*"; } || true; }
info()  { $SILENT || { [[ $VERBOSITY -ge 2 ]] && echo -e "$(_c "$B" '[i]') $*"; } || true; }
verb()  { $SILENT || { [[ $VERBOSITY -ge 3 ]] && echo -e "$(_c "$DIM" '[~]') $*"; } || true; }
debug() { $SILENT || { [[ $VERBOSITY -ge 4 ]] && echo -e "$(_c "$M" '[d]') $*"; } || true; }
trace() { $SILENT || { [[ $VERBOSITY -ge 5 ]] && echo -e "$(_c "$DIM" '[t]') $*"; } || true; }
ok()    {            { [[ $VERBOSITY -ge 1 ]] && echo -e "$(_c "$G" '[+]') $*"; } || true; }
warn()  { $SILENT || { [[ $VERBOSITY -ge 1 ]] && echo -e "$(_c "$Y" '[!]') $*"; } || true; }
err()   { echo -e "$(_c "$R" '[✗]') $*" >&2; }
die()   { err "$*"; exit 1; }

# ════════════════════════════════════════════════════════════════════
#  BANNER + USAGE
# ════════════════════════════════════════════════════════════════════
banner() {
  $SILENT && return 0
  [[ $VERBOSITY -ge 1 ]] || return 0
  $NO_COLOR && {
    echo "  scrapper_rapper  ·  spider & extractor"
    echo "  spidering · js hunting · file extraction · recon"
    return 0
  }
  echo -e "${C}"
  echo '  ╔═══════════════════════════════════════════════════╗'
  echo '  ║        scrapper_rapper  ·  spider & extractor     ║'
  echo '  ║    spidering  ·  js hunting  ·  file extraction   ║'
  echo '  ╚═══════════════════════════════════════════════════╝'
  echo -e "${N}"
}

usage() {
  local S="${G}" E="${N}" H="${BOLD}" X="${N}" D="${DIM}"
  $NO_COLOR && { S=''; E=''; H=''; X=''; D=''; }
  cat <<EOF
${H}Usage:${X}
  $(basename "$0") -u <url> [options]

${H}Core:${X}
  ${S}-u${E}, ${S}--url${E}          <url>       Target URL                          (required)
  ${S}-o${E}, ${S}--output${E}       <dir>       Output directory         (default: domain_scrape/)
  ${S}-v${E}, ${S}--verbosity${E}    <1-5>       Verbosity level          (default: 1)
      ${D}1=status  2=info  3=verbose  4=debug  5=trace${X}
  ${S}-q${E}, ${S}--silent${E}                   Silent — only print final results
      ${S}--no-color${E}                         Disable color output
      ${S}--append${E}                           Append to existing output dir

${H}Spider:${X}
  ${S}-d${E}, ${S}--depth${E}        <1-20>      Crawl depth              (default: 3)
  ${S}-t${E}, ${S}--threads${E}      <n>         Concurrent requests      (default: 10)
  ${S}-m${E}, ${S}--max-pages${E}    <n>         Max pages to crawl       (default: unlimited)
  ${S}-D${E}, ${S}--delay${E}        <sec>       Delay between requests   (default: 0)
      ${S}--rate${E}         <n>         Max requests/sec         (default: unlimited)

${H}Network:${X}
  ${S}-T${E}, ${S}--timeout${E}      <sec>       Request timeout          (default: 15)
  ${S}-r${E}, ${S}--retries${E}      <n>         Retry attempts           (default: 2)
  ${S}-A${E}, ${S}--user-agent${E}   <str>       Custom User-Agent
  ${S}-x${E}, ${S}--proxy${E}        <url>       Proxy URL  (http://... or socks5://...)
  ${S}-b${E}, ${S}--cookie${E}       <str>       Cookies string  (name=val; name2=val2)
  ${S}-H${E}, ${S}--header${E}       <str>       Extra header  (repeatable: -H "X: v")
      ${S}--no-redirect${E}                      Do not follow redirects

${H}Auth:${X}
      ${S}--auth${E}         <user:pass>  HTTP Basic auth
      ${S}--token${E}        <token>      Bearer token (Authorization header)

${H}Scope:${X}
  ${S}-S${E}, ${S}--subdomains${E}               Include subdomains in crawl
  ${S}-e${E}, ${S}--external${E}                 Follow external links
      ${S}--exclude${E}      <regex>     Exclude URLs matching pattern
      ${S}--include${E}      <regex>     Only crawl URLs matching pattern
      ${S}--respect-robots${E}           Respect robots.txt rules

${H}Extraction:${X}
      ${S}--no-js${E}                           Skip JS extraction
      ${S}--no-css${E}                          Skip CSS extraction
      ${S}--no-docs${E}                         Skip document extraction
      ${S}--no-images${E}                       Skip image extraction
      ${S}--emails${E}                          Extract email addresses
      ${S}--secrets${E}                         Scan JS for secrets/keys/tokens
      ${S}--endpoints${E}                       Extract API endpoints from JS
      ${S}--forms${E}                           Extract forms (action + inputs)
      ${S}--comments${E}                        Extract HTML comments
      ${S}--params${E}                          Extract URL parameters
      ${S}--download-js${E}                     Download JS files locally
      ${S}--download-css${E}                    Download CSS files locally
      ${S}--save-html${E}                       Save raw HTML pages

${H}Passive Sources:${X}
  ${S}-w${E}, ${S}--wayback${E}                  Pull URLs from Wayback Machine
  ${S}-g${E}, ${S}--gau${E}                      Pull URLs via gau (getallurls)
      ${S}--katana${E}                          Use katana crawler (if installed)
      ${S}--gospider${E}                        Use gospider crawler (if installed)
      ${S}--hakrawler${E}                       Use hakrawler (if installed)
      ${S}--subfinder${E}                       Subdomain enum first (subfinder)

${H}Output:${X}
      ${S}--json${E}                            Also write results as JSON

${H}Full mode:${X}
      ${S}--full${E}                            Enable all extractions + JSON output
                                       (emails, secrets, endpoints, forms,
                                        comments, params, json)

${H}Misc:${X}
  ${S}-h${E}, ${S}--help${E}                     Show this help

${H}Verbosity levels:${X}
  ${S}1${E} · status only — key results              (default)
  ${S}2${E} · info  — steps + results
  ${S}3${E} · verbose — per-URL progress
  ${S}4${E} · debug  — empty responses, skips
  ${S}5${E} · trace  — link counts, raw matches

${H}Examples:${X}
  $(basename "$0") -u https://example.com
  $(basename "$0") -u https://example.com -v 3 -d 5 -t 20 --wayback --gau
  $(basename "$0") -u https://example.com --emails --secrets --endpoints
  $(basename "$0") -u https://example.com --proxy http://127.0.0.1:8080 --auth admin:pass
  $(basename "$0") -u https://example.com -S --subdomains --json --download-js
  $(basename "$0") -u https://example.com --exclude '\.(png|jpg|gif)$' --depth 10
  $(basename "$0") -u https://example.com -q --no-color -o /tmp/out
  $(basename "$0") -u https://example.com --full
  $(basename "$0") -u https://example.com --full -v 3 -d 5 --wayback --gau
EOF
}

# ════════════════════════════════════════════════════════════════════
#  ARGUMENT PARSING
# ════════════════════════════════════════════════════════════════════
[[ $# -eq 0 ]] && { banner; usage; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    # core
    -u|--url)            TARGET="$2";              shift 2 ;;
    -o|--output)         OUTPUT_DIR="$2";          shift 2 ;;
    -v|--verbosity)      VERBOSITY="$2";           shift 2 ;;
    -q|--silent)         SILENT=true;              shift   ;;
    --no-color)          NO_COLOR=true;            shift   ;;
    --append)            APPEND=true;              shift   ;;
    # spider
    -d|--depth)          DEPTH="$2";               shift 2 ;;
    -t|--threads)        THREADS="$2";             shift 2 ;;
    -m|--max-pages)      MAX_PAGES="$2";           shift 2 ;;
    -D|--delay)          DELAY="$2";               shift 2 ;;
    --rate)              RATE="$2";                shift 2 ;;
    # network
    -T|--timeout)        TIMEOUT="$2";             shift 2 ;;
    -r|--retries)        RETRIES="$2";             shift 2 ;;
    -A|--user-agent)     USER_AGENT="$2";          shift 2 ;;
    -x|--proxy)          PROXY="$2";               shift 2 ;;
    -b|--cookie)         COOKIES="$2";             shift 2 ;;
    -H|--header)         EXTRA_HEADERS+=("$2");    shift 2 ;;
    --no-redirect)       FOLLOW_REDIRECTS=false;   shift   ;;
    # auth
    --auth)              BASIC_AUTH="$2";          shift 2 ;;
    --token)             BEARER_TOKEN="$2";        shift 2 ;;
    # scope
    -S|--subdomains)     SUBDOMAINS=true;          shift   ;;
    -e|--external)       EXTERNAL=true;            shift   ;;
    --exclude)           EXCLUDE_PATTERN="$2";     shift 2 ;;
    --include)           INCLUDE_PATTERN="$2";     shift 2 ;;
    --respect-robots)    RESPECT_ROBOTS=true;      shift   ;;
    # extraction
    --no-js)             EXTRACT_JS=false;         shift   ;;
    --no-css)            EXTRACT_CSS=false;        shift   ;;
    --no-docs)           EXTRACT_DOCS=false;       shift   ;;
    --no-images)         EXTRACT_IMAGES=false;     shift   ;;
    --emails)            EXTRACT_EMAILS=true;      shift   ;;
    --secrets)           EXTRACT_SECRETS=true;     shift   ;;
    --endpoints)         EXTRACT_ENDPOINTS=true;   shift   ;;
    --forms)             EXTRACT_FORMS=true;       shift   ;;
    --comments)          EXTRACT_COMMENTS=true;    shift   ;;
    --params)            EXTRACT_PARAMS=true;      shift   ;;
    --download-js)       DOWNLOAD_JS=true;         shift   ;;
    --download-css)      DOWNLOAD_CSS=true;        shift   ;;
    --save-html)         SAVE_HTML=true;           shift   ;;
    # passive sources
    -w|--wayback)        USE_WAYBACK=true;         shift   ;;
    -g|--gau)            USE_GAU=true;             shift   ;;
    --katana)            USE_KATANA=true;          shift   ;;
    --gospider)          USE_GOSPIDER=true;        shift   ;;
    --hakrawler)         USE_HAKRAWLER=true;       shift   ;;
    --subfinder)         USE_SUBFINDER=true;       shift   ;;
    # output
    --json)              JSON_OUTPUT=true;         shift   ;;
    # full mode
    --full)
      EXTRACT_EMAILS=true; EXTRACT_SECRETS=true; EXTRACT_ENDPOINTS=true
      EXTRACT_FORMS=true;  EXTRACT_COMMENTS=true; EXTRACT_PARAMS=true
      JSON_OUTPUT=true
      shift ;;
    # misc
    -h|--help)           banner; usage;            exit 0  ;;
    *) die "Unknown option: $1  — use -h for help" ;;
  esac
done

# ════════════════════════════════════════════════════════════════════
#  VALIDATE
# ════════════════════════════════════════════════════════════════════
[[ -z "$TARGET" ]]            && die "Target URL required (-u <url>)"
[[ "$VERBOSITY" =~ ^[1-5]$ ]] || die "Verbosity must be 1–5"
[[ "$DEPTH"     =~ ^[0-9]+$ ]] || die "Depth must be a positive integer"
[[ "$THREADS"   =~ ^[0-9]+$ ]] || die "Threads must be a positive integer"
[[ "$TIMEOUT"   =~ ^[0-9]+$ ]] || die "Timeout must be a positive integer"
command -v curl &>/dev/null   || die "curl is required but not found"

TARGET="${TARGET%/}"
[[ "$TARGET" =~ ^https?:// ]] || TARGET="https://$TARGET"
DOMAIN=$(echo "$TARGET" | sed -E 's|https?://([^/:]+).*|\1|')
BASE_DOMAIN=$(echo "$DOMAIN" | sed -E 's/^[^.]+\.//' )

[[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="${DOMAIN}_scrape"

# ════════════════════════════════════════════════════════════════════
#  SETUP
# ════════════════════════════════════════════════════════════════════
if $APPEND; then
  mkdir -p "$OUTPUT_DIR"/{js,css,docs,endpoints,raw,html,extra}
else
  rm -rf "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR"/{js,css,docs,endpoints,raw,html,extra}
fi

banner

log "Target     : ${C}$TARGET${N}"
log "Domain     : ${C}$DOMAIN${N}"
log "Output     : ${C}$OUTPUT_DIR/${N}"
info "Depth $DEPTH  ·  Threads $THREADS  ·  Timeout ${TIMEOUT}s  ·  Verbosity $VERBOSITY"
[[ -n "$PROXY"       ]] && info "Proxy      : $PROXY"
[[ -n "$BASIC_AUTH"  ]] && info "Auth       : Basic (${BASIC_AUTH%%:*}:***)"
[[ -n "$BEARER_TOKEN" ]] && info "Auth       : Bearer token"
$SUBDOMAINS   && info "Scope      : subdomains included  (*.$BASE_DOMAIN)"
$EXTERNAL     && info "Scope      : external links enabled"
$RESPECT_ROBOTS && info "Robots.txt : respected"
[[ -n "$EXCLUDE_PATTERN" ]] && info "Exclude    : $EXCLUDE_PATTERN"
[[ -n "$INCLUDE_PATTERN" ]] && info "Include    : $INCLUDE_PATTERN"

TMP=$(mktemp -d /tmp/scrapper_rapper.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

ALL_URLS="$TMP/all_urls.txt"
CRAWLED="$TMP/crawled.txt"
QUEUE="$TMP/queue.txt"
SEEN="$TMP/seen.txt"
ROBOTS_DISALLOW="$TMP/robots_disallow.txt"

touch "$ALL_URLS" "$CRAWLED" "$QUEUE" "$SEEN" "$ROBOTS_DISALLOW"

PAGE_COUNT=0  # global crawl counter

# ════════════════════════════════════════════════════════════════════
#  CURL WRAPPER
# ════════════════════════════════════════════════════════════════════
_curl() {
  local url="$1"
  local args=( -s --max-time "$TIMEOUT" --retry "$RETRIES"
               -A "$USER_AGENT"
               -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
               -H "Accept-Language: en-US,en;q=0.5"
               -H "Connection: keep-alive" )

  $FOLLOW_REDIRECTS  && args+=( -L )
  [[ -n "$PROXY"       ]] && args+=( --proxy "$PROXY" )
  [[ -n "$BASIC_AUTH"  ]] && args+=( -u "$BASIC_AUTH" )
  [[ -n "$BEARER_TOKEN" ]] && args+=( -H "Authorization: Bearer $BEARER_TOKEN" )
  [[ -n "$COOKIES"     ]] && args+=( -b "$COOKIES" )

  for h in "${EXTRA_HEADERS[@]+"${EXTRA_HEADERS[@]}"}"; do
    args+=( -H "$h" )
  done

  debug "GET $url"
  curl "${args[@]}" "$url" 2>/dev/null || true

  # rate / delay
  [[ $RATE -gt 0 ]] && sleep "$(echo "scale=3; 1/$RATE" | bc)"
  [[ $DELAY -gt 0 ]] && sleep "$DELAY"
  return 0
}

# ════════════════════════════════════════════════════════════════════
#  ROBOTS.TXT
# ════════════════════════════════════════════════════════════════════
fetch_robots() {
  $RESPECT_ROBOTS || return 0
  log "Fetching robots.txt"
  local robots
  robots=$(_curl "$TARGET/robots.txt" 2>/dev/null || true)
  echo "$robots" \
    | grep -iP '^\s*Disallow:' \
    | sed -E 's/^\s*Disallow:\s*//' \
    | grep -vP '^\s*$' \
    | sed "s|^|$TARGET|" \
    >> "$ROBOTS_DISALLOW" || true
  local cnt; cnt=$(wc -l < "$ROBOTS_DISALLOW")
  info "robots.txt : $cnt disallowed paths"
}

is_allowed() {
  local url="$1"
  $RESPECT_ROBOTS || return 0
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    [[ "$url" == "$pat"* ]] && return 1
  done < "$ROBOTS_DISALLOW"
  return 0
}

# ════════════════════════════════════════════════════════════════════
#  SCOPE FILTER
# ════════════════════════════════════════════════════════════════════
in_scope() {
  local url="$1"

  # include filter
  [[ -n "$INCLUDE_PATTERN" ]] && ! echo "$url" | grep -qP "$INCLUDE_PATTERN" && return 1

  # exclude filter
  [[ -n "$EXCLUDE_PATTERN" ]] && echo "$url" | grep -qP "$EXCLUDE_PATTERN" && return 1

  # domain scope
  if $EXTERNAL; then
    return 0
  elif $SUBDOMAINS; then
    echo "$url" | grep -qP "https?://([^/]+\.)?${BASE_DOMAIN//./\\.}" && return 0
  else
    echo "$url" | grep -qF "$DOMAIN" && return 0
  fi
  return 1
}

# ════════════════════════════════════════════════════════════════════
#  URL NORMALISATION
# ════════════════════════════════════════════════════════════════════
normalise_url() {
  local url="$1" base="$2"
  url=$(echo "$url" | sed -E \
    -e "s|^//|https://|"       \
    -e "s|^/([^/])|$base/\1|" \
    -e "s|^([^h][^t])|$base/\1|")
  echo "$url" | grep -oP "https?://[^\s\"'<>]+" | sed 's|[?#].*||' || true
}

# ════════════════════════════════════════════════════════════════════
#  EXTRACTORS
# ════════════════════════════════════════════════════════════════════

# --- all href/src links ---
extract_urls() {
  local html="$1" base="$2"
  echo "$html" \
    | grep -oP '(?:href|src|action|data-src|data-href)="[^"#][^"]*"' \
    | grep -oP '(?<=")[^"]+' \
    | grep -vP '^\s*$|^mailto:|^tel:|^javascript:|^#|^data:' \
    | while IFS= read -r u; do normalise_url "$u" "$base"; done \
    | grep -P "^https?://" | sort -u || true
}

# --- JS files ---
extract_js() {
  local html="$1" base="$2"
  echo "$html" \
    | grep -oP '(?:src|data-src)="[^"]+\.js[^"]*"' \
    | grep -oP '(?<=")[^"]+' \
    | while IFS= read -r u; do normalise_url "$u" "$base"; done \
    | grep -P "^https?://" | sort -u || true
}

# --- CSS files ---
extract_css() {
  local html="$1" base="$2"
  echo "$html" \
    | grep -oP '(?:href|src)="[^"]+\.css[^"]*"' \
    | grep -oP '(?<=")[^"]+' \
    | while IFS= read -r u; do normalise_url "$u" "$base"; done \
    | grep -P "^https?://" | sort -u || true
}

# --- generic asset by extension ---
extract_ext() {
  local html="$1" base="$2" ext="$3"
  echo "$html" \
    | grep -oP "(?:href|src)=\"[^\"]+\.$ext[^\"]*\"" \
    | grep -oP '(?<=")[^"]+' \
    | while IFS= read -r u; do normalise_url "$u" "$base"; done \
    | grep -P "^https?://" | sort -u || true
}

# --- emails ---
extract_emails() {
  local html="$1"
  echo "$html" \
    | grep -oP '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}' \
    | sort -u || true
}

# --- HTML comments ---
extract_comments() {
  local html="$1"
  echo "$html" \
    | grep -oP '<!--.*?-->' \
    | grep -v '^\s*<!--\s*-->\s*$' \
    | sort -u || true
}

# --- form actions + inputs ---
extract_forms() {
  local html="$1" base="$2"
  echo "$html" \
    | grep -oP '<form[^>]*>' \
    | grep -oP 'action="[^"]+"' \
    | grep -oP '(?<=action=")[^"]+' \
    | while IFS= read -r u; do normalise_url "$u" "$base"; done \
    | sort -u || true
}

# --- URL params ---
extract_params() {
  local html="$1"
  echo "$html" \
    | grep -oP 'https?://[^\s"<>]+\?[^\s"<>]+' \
    | grep -oP '\?[^\s"<>]+' \
    | grep -oP '(?<=\?|&)[^&=]+(?==)' \
    | sort -u || true
}

# --- API endpoints from JS ---
extract_api_endpoints() {
  local js="$1"
  echo "$js" \
    | grep -oP '(?:"|'"'"')(\/[a-zA-Z0-9_\-\/\.]+(?:\/[a-zA-Z0-9_\-]+)*)(?:"|'"'"')' \
    | grep -oP '(?<="|'"'"')\/[^"'"'"']+' \
    | grep -vP '\.(js|css|png|jpg|gif|svg|ico|woff|ttf)$' \
    | sort -u || true
}

# --- secrets / sensitive patterns ---
SECRETS_PATTERNS=(
  'api[_\-]?key\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{16,}'
  'secret[_\-]?key\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{16,}'
  'access[_\-]?token\s*[:=]\s*["\x27]?[A-Za-z0-9_\-\.]{16,}'
  'auth[_\-]?token\s*[:=]\s*["\x27]?[A-Za-z0-9_\-\.]{16,}'
  'private[_\-]?key\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{16,}'
  'password\s*[:=]\s*["\x27][^"]{6,}'
  'client[_\-]?secret\s*[:=]\s*["\x27]?[A-Za-z0-9_\-]{8,}'
  'AKIA[0-9A-Z]{16}'                # AWS Access Key ID
  'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'  # JWT
  'AIza[0-9A-Za-z_\-]{35}'         # Google API key
  'ghp_[A-Za-z0-9]{36}'            # GitHub personal token
  'xox[baprs]-[0-9A-Za-z\-]+'      # Slack token
  'Bearer\s+[A-Za-z0-9_\-\.]{20,}' # Bearer tokens
  'mongodb(\+srv)?://[^"<>\s]+'     # MongoDB URI
  'postgres://[^"<>\s]+'            # PostgreSQL URI
)

extract_secrets() {
  local content="$1"
  local found=false
  for pattern in "${SECRETS_PATTERNS[@]}"; do
    local match
    match=$(echo "$content" | grep -oiP "$pattern" 2>/dev/null || true)
    [[ -n "$match" ]] && { echo "$match"; found=true; }
  done
  $found || true
}

# ════════════════════════════════════════════════════════════════════
#  SPIDER
# ════════════════════════════════════════════════════════════════════
spider() {
  log "Starting spider  (depth $DEPTH$([ "$MAX_PAGES" -gt 0 ] && echo "  ·  max $MAX_PAGES pages"))"
  echo "$TARGET" > "$QUEUE"
  echo "$TARGET" >> "$SEEN"
  echo "$TARGET" >> "$ALL_URLS"

  local current_depth=0

  while [[ -s "$QUEUE" ]] && [[ $current_depth -lt $DEPTH ]]; do
    current_depth=$(( current_depth + 1 ))
    local next_queue="$TMP/queue_d${current_depth}.txt"
    > "$next_queue"

    local line_count
    line_count=$(wc -l < "$QUEUE")
    info "Depth $current_depth/$DEPTH  — ${Y}$line_count${N} URLs queued"

    local count=0
    while IFS= read -r url; do
      # max-pages guard
      [[ $MAX_PAGES -gt 0 && $PAGE_COUNT -ge $MAX_PAGES ]] && {
        warn "Max pages ($MAX_PAGES) reached — stopping spider"
        break 2
      }

      count=$(( count + 1 ))
      PAGE_COUNT=$(( PAGE_COUNT + 1 ))

      # robots check
      is_allowed "$url" || { debug "robots: blocked $url"; continue; }

      verb "[$current_depth/$DEPTH · $count/$line_count] $url"

      local html
      html=$(_curl "$url")
      [[ -z "$html" ]] && { debug "empty response: $url"; continue; }

      echo "$url" >> "$CRAWLED"

      # save html
      if $SAVE_HTML; then
        local slug
        slug=$(echo "$url" | sed 's|https\?://||; s|[^a-zA-Z0-9]|_|g')
        echo "$html" > "$OUTPUT_DIR/html/${slug}.html"
      fi

      # ── collect linked URLs ──────────────────────────────────────
      local new_urls
      new_urls=$(extract_urls "$html" "$TARGET")
      local link_count=0
      while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        in_scope "$link" || continue
        if ! grep -qxF "$link" "$SEEN" 2>/dev/null; then
          echo "$link" >> "$SEEN"
          echo "$link" >> "$next_queue"
          echo "$link" >> "$ALL_URLS"
          link_count=$(( link_count + 1 ))
        fi
      done <<< "$new_urls"
      trace "  └─ $link_count new links found"

      # ── per-page extractions ─────────────────────────────────────
      $EXTRACT_JS   && extract_js  "$html" "$TARGET" >> "$TMP/js_raw.txt"
      $EXTRACT_CSS  && extract_css "$html" "$TARGET" >> "$TMP/css_raw.txt"

      if $EXTRACT_DOCS; then
        for ext in pdf doc docx xls xlsx pptx txt; do
          extract_ext "$html" "$TARGET" "$ext" >> "$TMP/docs_raw.txt"
        done
        for ext in zip tar gz 7z rar; do
          extract_ext "$html" "$TARGET" "$ext" >> "$TMP/archives_raw.txt"
        done
      fi

      $EXTRACT_IMAGES && {
        for ext in png jpg jpeg gif svg ico webp bmp; do
          extract_ext "$html" "$TARGET" "$ext" >> "$TMP/images_raw.txt"
        done
      }

      $EXTRACT_EMAILS   && extract_emails   "$html" >> "$TMP/emails_raw.txt"
      $EXTRACT_COMMENTS && extract_comments "$html" >> "$TMP/comments_raw.txt"
      $EXTRACT_FORMS    && extract_forms    "$html" "$TARGET" >> "$TMP/forms_raw.txt"
      $EXTRACT_PARAMS   && extract_params   "$html" >> "$TMP/params_raw.txt"

    done < "$QUEUE"

    cp "$next_queue" "$QUEUE"
  done

  local crawled_count
  crawled_count=$(wc -l < "$CRAWLED")
  ok "Spider done  — ${G}$crawled_count${N} pages crawled"
}

# ════════════════════════════════════════════════════════════════════
#  JS EXTRACTION  (core command + spider harvest)
# ════════════════════════════════════════════════════════════════════
run_js_extraction() {
  $EXTRACT_JS || return 0
  log "Extracting JS files"
  local jsfile="$OUTPUT_DIR/js/jsfiles.txt"
  local url="$TARGET"

  # core command (as provided)
  (
    echo "$url"
    curl -s "$url" \
      | grep -oP '(?<=src=")[^"]+\.js[^"]*' \
      | sed -E "s|^/|$url/|; s|^([^h])|$url/\1|" || true
  ) | sort -u >> "$jsfile" || true

  # spider harvest
  [[ -f "$TMP/js_raw.txt" ]] && { sort -u "$TMP/js_raw.txt" >> "$jsfile"; }

  sort -u -o "$jsfile" "$jsfile"

  local js_count
  js_count=$(grep -c . "$jsfile" 2>/dev/null || echo 0)
  ok "JS files   : ${G}$js_count${N} → ${C}$jsfile${N}"
}

# ════════════════════════════════════════════════════════════════════
#  JS DEEP ANALYSIS  (secrets + API endpoints)
# ════════════════════════════════════════════════════════════════════
analyse_js() {
  ( $EXTRACT_SECRETS || $EXTRACT_ENDPOINTS ) || return 0

  local jsfile="$OUTPUT_DIR/js/jsfiles.txt"
  [[ -s "$jsfile" ]] || return 0

  log "Analysing JS files"
  local total; total=$(grep -c . "$jsfile" 2>/dev/null || echo 0)
  local count=0

  while IFS= read -r jsurl; do
    [[ -z "$jsurl" ]] && continue
    count=$(( count + 1 ))
    verb "JS [$count/$total] $jsurl"

    local js_content
    js_content=$(_curl "$jsurl")
    [[ -z "$js_content" ]] && { debug "empty JS: $jsurl"; continue; }

    $EXTRACT_SECRETS   && {
      local hits
      hits=$(extract_secrets "$js_content")
      [[ -n "$hits" ]] && {
        echo "# $jsurl" >> "$OUTPUT_DIR/extra/secrets.txt"
        echo "$hits"    >> "$OUTPUT_DIR/extra/secrets.txt"
        echo ""         >> "$OUTPUT_DIR/extra/secrets.txt"
        warn "Secret pattern found in: $jsurl"
      }
    }

    $EXTRACT_ENDPOINTS && {
      extract_api_endpoints "$js_content" >> "$OUTPUT_DIR/extra/api_endpoints.txt"
    }

  done < "$jsfile"

  $EXTRACT_ENDPOINTS && sort -u -o "$OUTPUT_DIR/extra/api_endpoints.txt" \
                                   "$OUTPUT_DIR/extra/api_endpoints.txt" 2>/dev/null || true
  local sec_count ep_count
  $EXTRACT_SECRETS   && sec_count=$(grep -c '^#' "$OUTPUT_DIR/extra/secrets.txt"   2>/dev/null || echo 0) \
                     && ok "Secrets    : ${R}$sec_count${N} JS files with matches → ${C}$OUTPUT_DIR/extra/secrets.txt${N}"
  $EXTRACT_ENDPOINTS && ep_count=$(grep -c .   "$OUTPUT_DIR/extra/api_endpoints.txt" 2>/dev/null || echo 0) \
                     && ok "Endpoints  : ${G}$ep_count${N} → ${C}$OUTPUT_DIR/extra/api_endpoints.txt${N}"
}

# ════════════════════════════════════════════════════════════════════
#  DOWNLOAD JS / CSS
# ════════════════════════════════════════════════════════════════════
download_assets() {
  local type="$1" src="$2" dest_dir="$3"
  [[ -s "$src" ]] || return 0
  log "Downloading $type files"
  mkdir -p "$dest_dir"
  local total; total=$(grep -c . "$src" 2>/dev/null || echo 0)
  local count=0
  while IFS= read -r url; do
    [[ -z "$url" ]] && continue
    count=$(( count + 1 ))
    local fname
    fname=$(echo "$url" | sed -E 's|https?://||; s|[/?&=]|_|g')
    verb "Downloading [$count/$total] $fname"
    _curl "$url" > "$dest_dir/${fname}" 2>/dev/null || debug "failed: $url"
  done < "$src"
  ok "Downloaded : ${G}$count${N} $type files → ${C}$dest_dir/${N}"
}

# ════════════════════════════════════════════════════════════════════
#  PASSIVE SOURCES
# ════════════════════════════════════════════════════════════════════
pull_wayback() {
  command -v waybackurls &>/dev/null || { warn "waybackurls not installed — skipping"; return; }
  log "Wayback Machine"
  local out="$OUTPUT_DIR/endpoints/wayback.txt"
  echo "$DOMAIN" | waybackurls 2>/dev/null | grep -iF "$DOMAIN" | sort -u > "$out"
  cat "$out" >> "$ALL_URLS"
  local cnt; cnt=$(wc -l < "$out")
  ok "Wayback    : ${G}$cnt${N} → ${C}$out${N}"
}

pull_gau() {
  command -v gau &>/dev/null || { warn "gau not installed — skipping"; return; }
  log "GAU (getallurls)"
  local out="$OUTPUT_DIR/endpoints/gau.txt"
  gau "$DOMAIN" 2>/dev/null | sort -u > "$out"
  cat "$out" >> "$ALL_URLS"
  local cnt; cnt=$(wc -l < "$out")
  ok "GAU        : ${G}$cnt${N} → ${C}$out${N}"
}

pull_katana() {
  command -v katana &>/dev/null || { warn "katana not installed — skipping"; return; }
  log "Katana crawler"
  local out="$OUTPUT_DIR/endpoints/katana.txt"
  local args=( -u "$TARGET" -d "$DEPTH" -silent )
  [[ -n "$PROXY" ]] && args+=( -proxy "$PROXY" )
  katana "${args[@]}" 2>/dev/null | sort -u > "$out"
  cat "$out" >> "$ALL_URLS"
  local cnt; cnt=$(wc -l < "$out")
  ok "Katana     : ${G}$cnt${N} → ${C}$out${N}"
}

pull_gospider() {
  command -v gospider &>/dev/null || { warn "gospider not installed — skipping"; return; }
  log "GoSpider crawler"
  local out="$OUTPUT_DIR/endpoints/gospider.txt"
  gospider -s "$TARGET" -d "$DEPTH" -t "$THREADS" -q 2>/dev/null \
    | grep -oP 'https?://[^\s]+' | sort -u > "$out"
  cat "$out" >> "$ALL_URLS"
  local cnt; cnt=$(wc -l < "$out")
  ok "GoSpider   : ${G}$cnt${N} → ${C}$out${N}"
}

pull_hakrawler() {
  command -v hakrawler &>/dev/null || { warn "hakrawler not installed — skipping"; return; }
  log "Hakrawler"
  local out="$OUTPUT_DIR/endpoints/hakrawler.txt"
  echo "$TARGET" | hakrawler -d "$DEPTH" -t "$THREADS" 2>/dev/null | sort -u > "$out"
  cat "$out" >> "$ALL_URLS"
  local cnt; cnt=$(wc -l < "$out")
  ok "Hakrawler  : ${G}$cnt${N} → ${C}$out${N}"
}

run_subfinder() {
  command -v subfinder &>/dev/null || { warn "subfinder not installed — skipping"; return; }
  log "Subfinder — enumerating subdomains"
  local out="$OUTPUT_DIR/endpoints/subdomains.txt"
  subfinder -d "$BASE_DOMAIN" -silent 2>/dev/null | sort -u > "$out"
  local cnt; cnt=$(wc -l < "$out")
  ok "Subfinder  : ${G}$cnt${N} subdomains → ${C}$out${N}"
  # prepend discovered subdomains to queue
  while IFS= read -r sub; do
    [[ -z "$sub" ]] && continue
    local sub_url="https://$sub"
    if ! grep -qxF "$sub_url" "$SEEN" 2>/dev/null; then
      echo "$sub_url" >> "$SEEN"
      echo "$sub_url" >> "$QUEUE"
      echo "$sub_url" >> "$ALL_URLS"
    fi
  done < "$out"
}

# ════════════════════════════════════════════════════════════════════
#  CATEGORISE
# ════════════════════════════════════════════════════════════════════
categorize() {
  info "Categorising collected URLs"
  sort -u "$ALL_URLS" > "$OUTPUT_DIR/endpoints/all_urls.txt"
  local all="$OUTPUT_DIR/endpoints/all_urls.txt"

  # JS
  $EXTRACT_JS && {
    grep -iP '\.(js)(\?|$)' "$all" 2>/dev/null \
      >> "$OUTPUT_DIR/js/jsfiles.txt" || true
    sort -u -o "$OUTPUT_DIR/js/jsfiles.txt" "$OUTPUT_DIR/js/jsfiles.txt" 2>/dev/null || true
  }

  # CSS
  $EXTRACT_CSS && {
    [[ -f "$TMP/css_raw.txt" ]] && cat "$TMP/css_raw.txt" >> "$OUTPUT_DIR/css/cssfiles.txt"
    grep -iP '\.(css)(\?|$)' "$all" 2>/dev/null \
      >> "$OUTPUT_DIR/css/cssfiles.txt" || true
    sort -u -o "$OUTPUT_DIR/css/cssfiles.txt" "$OUTPUT_DIR/css/cssfiles.txt" 2>/dev/null || true
  }

  # docs
  $EXTRACT_DOCS && {
    [[ -f "$TMP/docs_raw.txt"     ]] && sort -u "$TMP/docs_raw.txt"     > "$OUTPUT_DIR/docs/docs.txt"
    [[ -f "$TMP/archives_raw.txt" ]] && sort -u "$TMP/archives_raw.txt" > "$OUTPUT_DIR/docs/archives.txt"
    grep -iP '\.(pdf|docx?|xlsx?|pptx?|txt)(\?|$)' "$all" 2>/dev/null \
      >> "$OUTPUT_DIR/docs/docs.txt" || true
    grep -iP '\.(zip|tar|gz|7z|rar)(\?|$)' "$all" 2>/dev/null \
      >> "$OUTPUT_DIR/docs/archives.txt" || true
    sort -u -o "$OUTPUT_DIR/docs/docs.txt"     "$OUTPUT_DIR/docs/docs.txt"     2>/dev/null || true
    sort -u -o "$OUTPUT_DIR/docs/archives.txt" "$OUTPUT_DIR/docs/archives.txt" 2>/dev/null || true
  }

  # images
  $EXTRACT_IMAGES && {
    [[ -f "$TMP/images_raw.txt" ]] && cat "$TMP/images_raw.txt" >> "$OUTPUT_DIR/raw/images.txt"
    grep -iP '\.(png|jpg|jpeg|gif|svg|ico|webp|bmp)(\?|$)' "$all" 2>/dev/null \
      >> "$OUTPUT_DIR/raw/images.txt" || true
    sort -u -o "$OUTPUT_DIR/raw/images.txt" "$OUTPUT_DIR/raw/images.txt" 2>/dev/null || true
  }

  # dynamic pages
  grep -iP '\.(php|asp|aspx|jsp|py|rb|go|cfm)(\?|$)' "$all" 2>/dev/null \
    > "$OUTPUT_DIR/endpoints/dynamic.txt" || true

  # extra extractions
  $EXTRACT_EMAILS   && [[ -f "$TMP/emails_raw.txt"   ]] && sort -u "$TMP/emails_raw.txt"   > "$OUTPUT_DIR/extra/emails.txt"   || true
  $EXTRACT_COMMENTS && [[ -f "$TMP/comments_raw.txt" ]] && sort -u "$TMP/comments_raw.txt" > "$OUTPUT_DIR/extra/comments.txt" || true
  $EXTRACT_FORMS    && [[ -f "$TMP/forms_raw.txt"    ]] && sort -u "$TMP/forms_raw.txt"    > "$OUTPUT_DIR/extra/forms.txt"    || true
  $EXTRACT_PARAMS   && [[ -f "$TMP/params_raw.txt"   ]] && sort -u "$TMP/params_raw.txt"   > "$OUTPUT_DIR/extra/params.txt"   || true
}

# ════════════════════════════════════════════════════════════════════
#  JSON OUTPUT
# ════════════════════════════════════════════════════════════════════
_arr() { local f="$1"; [[ -s "$f" ]] && sed 's/.*/"&"/' "$f" | paste -sd, | sed 's/^/[/; s/$/]/' || echo "[]"; }

write_json() {
  $JSON_OUTPUT || return 0
  local jf="$OUTPUT_DIR/results.json"
  info "Writing JSON → $jf"

  cat > "$jf" <<JSONEOF
{
  "target": "$TARGET",
  "domain": "$DOMAIN",
  "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "all_urls":       $(_arr "$OUTPUT_DIR/endpoints/all_urls.txt"),
  "js_files":       $(_arr "$OUTPUT_DIR/js/jsfiles.txt"),
  "css_files":      $(_arr "$OUTPUT_DIR/css/cssfiles.txt"),
  "documents":      $(_arr "$OUTPUT_DIR/docs/docs.txt"),
  "archives":       $(_arr "$OUTPUT_DIR/docs/archives.txt"),
  "images":         $(_arr "$OUTPUT_DIR/raw/images.txt"),
  "dynamic_pages":  $(_arr "$OUTPUT_DIR/endpoints/dynamic.txt"),
  "emails":         $(_arr "$OUTPUT_DIR/extra/emails.txt"),
  "forms":          $(_arr "$OUTPUT_DIR/extra/forms.txt"),
  "params":         $(_arr "$OUTPUT_DIR/extra/params.txt"),
  "api_endpoints":  $(_arr "$OUTPUT_DIR/extra/api_endpoints.txt")
}
JSONEOF
  ok "JSON       : ${C}$jf${N}"
}

# ════════════════════════════════════════════════════════════════════
#  SUMMARY
# ════════════════════════════════════════════════════════════════════
_cnt() { if [[ -f "$1" ]]; then grep -c . "$1" 2>/dev/null || true; else echo 0; fi; }

summary() {
  local all js css docs arcs imgs dyn em sec ep frm prm sub
  all=$(_cnt "$OUTPUT_DIR/endpoints/all_urls.txt")
  js=$(_cnt  "$OUTPUT_DIR/js/jsfiles.txt")
  css=$(_cnt "$OUTPUT_DIR/css/cssfiles.txt")
  docs=$(_cnt "$OUTPUT_DIR/docs/docs.txt")
  arcs=$(_cnt "$OUTPUT_DIR/docs/archives.txt")
  imgs=$(_cnt "$OUTPUT_DIR/raw/images.txt")
  dyn=$(_cnt  "$OUTPUT_DIR/endpoints/dynamic.txt")
  em=$(_cnt   "$OUTPUT_DIR/extra/emails.txt")
  sec=$(grep -c '^#' "$OUTPUT_DIR/extra/secrets.txt"    2>/dev/null || echo 0)
  ep=$(_cnt   "$OUTPUT_DIR/extra/api_endpoints.txt")
  frm=$(_cnt  "$OUTPUT_DIR/extra/forms.txt")
  prm=$(_cnt  "$OUTPUT_DIR/extra/params.txt")
  sub=$(_cnt  "$OUTPUT_DIR/endpoints/subdomains.txt")

  echo
  if $NO_COLOR; then
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║         scrapper_rapper — results             ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    printf  "  ║  %-24s  %6s  urls   ║\n"  "All URLs"         "$all"
    printf  "  ║  %-24s  %6s  files  ║\n"  "JavaScript"       "$js"
    printf  "  ║  %-24s  %6s  files  ║\n"  "CSS"              "$css"
    printf  "  ║  %-24s  %6s  files  ║\n"  "Documents"        "$docs"
    printf  "  ║  %-24s  %6s  files  ║\n"  "Archives"         "$arcs"
    printf  "  ║  %-24s  %6s  files  ║\n"  "Images"           "$imgs"
    printf  "  ║  %-24s  %6s  pages  ║\n"  "Dynamic pages"    "$dyn"
    [[ $sub  -gt 0 ]] && printf "  ║  %-24s  %6s         ║\n" "Subdomains"       "$sub"
    [[ $em   -gt 0 ]] && printf "  ║  %-24s  %6s         ║\n" "Emails"           "$em"
    [[ $sec  -gt 0 ]] && printf "  ║  %-24s  %6s  found  ║\n" "Secrets !"        "$sec"
    [[ $ep   -gt 0 ]] && printf "  ║  %-24s  %6s         ║\n" "API Endpoints"    "$ep"
    [[ $frm  -gt 0 ]] && printf "  ║  %-24s  %6s         ║\n" "Forms"            "$frm"
    [[ $prm  -gt 0 ]] && printf "  ║  %-24s  %6s         ║\n" "URL Params"       "$prm"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo "  ║  Output → $OUTPUT_DIR/"
    echo "  ╚═══════════════════════════════════════════════╝"
  else
    echo -e "${C}  ╔═══════════════════════════════════════════════╗${N}"
    echo -e "${C}  ║${N}         ${BOLD}scrapper_rapper — results${N}             ${C}║${N}"
    echo -e "${C}  ╠═══════════════════════════════════════════════╣${N}"
    printf "${C}  ║${N}  %-24s  ${G}%6s${N}  urls   ${C}║${N}\n"  "All URLs"         "$all"
    printf "${C}  ║${N}  %-24s  ${Y}%6s${N}  files  ${C}║${N}\n"  "JavaScript"       "$js"
    printf "${C}  ║${N}  %-24s  ${B}%6s${N}  files  ${C}║${N}\n"  "CSS"              "$css"
    printf "${C}  ║${N}  %-24s  ${M}%6s${N}  files  ${C}║${N}\n"  "Documents"        "$docs"
    printf "${C}  ║${N}  %-24s  ${M}%6s${N}  files  ${C}║${N}\n"  "Archives"         "$arcs"
    printf "${C}  ║${N}  %-24s  ${DIM}%6s${N}  files  ${C}║${N}\n" "Images"          "$imgs"
    printf "${C}  ║${N}  %-24s  ${B}%6s${N}  pages  ${C}║${N}\n"  "Dynamic pages"    "$dyn"
    [[ $sub  -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${C}%6s${N}         ${C}║${N}\n" "Subdomains"       "$sub"
    [[ $em   -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${Y}%6s${N}         ${C}║${N}\n" "Emails"           "$em"
    [[ $sec  -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${R}%6s${N}  found  ${C}║${N}\n" "Secrets !!"       "$sec"
    [[ $ep   -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${G}%6s${N}         ${C}║${N}\n" "API Endpoints"    "$ep"
    [[ $frm  -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${G}%6s${N}         ${C}║${N}\n" "Forms"            "$frm"
    [[ $prm  -gt 0 ]] && printf "${C}  ║${N}  %-24s  ${G}%6s${N}         ${C}║${N}\n" "URL Params"       "$prm"
    echo -e "${C}  ╠═══════════════════════════════════════════════╣${N}"
    echo -e "${C}  ║${N}  Output → ${C}$OUTPUT_DIR/${N}"
    echo -e "${C}  ╚═══════════════════════════════════════════════╝${N}"
  fi
}

# ════════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════════
main() {
  fetch_robots

  # passive sources that feed the queue before spidering
  $USE_SUBFINDER  && run_subfinder

  # built-in spider
  spider

  # JS extraction + deep analysis
  run_js_extraction
  analyse_js

  # passive URL sources (post-spider)
  $USE_WAYBACK    && pull_wayback
  $USE_GAU        && pull_gau
  $USE_KATANA     && pull_katana
  $USE_GOSPIDER   && pull_gospider
  $USE_HAKRAWLER  && pull_hakrawler

  # categorise everything
  categorize

  # optional downloads
  $DOWNLOAD_JS  && download_assets "JS"  "$OUTPUT_DIR/js/jsfiles.txt"  "$OUTPUT_DIR/js/downloaded"
  $DOWNLOAD_CSS && download_assets "CSS" "$OUTPUT_DIR/css/cssfiles.txt" "$OUTPUT_DIR/css/downloaded"

  # JSON
  write_json

  # final summary
  summary
}

main
