# scrapper_rapper

A fast, feature-rich web spider and content extraction tool built for security research, bug bounty hunting, and recon workflows. Combines active crawling with passive source integration to maximize URL discovery and surface exposure.

## Features

- Multi-depth website crawling with configurable threads and rate limiting
- JavaScript analysis: endpoint extraction, secret/key detection, file downloading
- Passive source integration: Wayback Machine, gau, katana, gospider, hakrawler
- Subdomain enumeration via subfinder
- Email harvesting, form extraction, HTML comment scraping, URL parameter collection
- Proxy support, custom headers, cookie injection, HTTP Basic and Bearer auth
- JSON output and verbose logging with 5 verbosity levels
- Robots.txt compliance option
- Zero mandatory dependencies beyond `curl` and standard Unix tools

## Installation

```bash
[git clone https://github.com/yourusername/scrapper_rapper](https://github.com/Fazliddin31/Scrapper-Rapper.git)
cd scrapper_rapper
chmod +x scrapper_rapper.sh
```

Optional: add to your PATH or create an alias:

```bash
echo 'alias scrapper_rapper="/path/to/scrapper_rapper.sh"' >> ~/.bashrc
source ~/.bashrc
```

## Dependencies

**Required:**
- `bash` 4.0+
- `curl`
- Standard Unix tools (`grep`, `sed`, `awk`, `sort`, `uniq`, etc.)

**Optional** (unlocks passive recon flags):

| Tool | Flag | Install |
|------|------|---------|
| [waybackurls](https://github.com/tomnomnom/waybackurls) | `-w` | `go install github.com/tomnomnom/waybackurls@latest` |
| [gau](https://github.com/lc/gau) | `-g` | `go install github.com/lc/gau/v2/cmd/gau@latest` |
| [katana](https://github.com/projectdiscovery/katana) | `--katana` | `go install github.com/projectdiscovery/katana/cmd/katana@latest` |
| [gospider](https://github.com/jaeles-project/gospider) | `--gospider` | `go install github.com/jaeles-project/gospider@latest` |
| [hakrawler](https://github.com/hakluke/hakrawler) | `--hakrawler` | `go install github.com/hakluke/hakrawler@latest` |
| [subfinder](https://github.com/projectdiscovery/subfinder) | `--subfinder` | `go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest` |

## Usage

```
scrapper_rapper.sh -u <url> [options]
```

### Core Options

| Flag | Description | Default |
|------|-------------|---------|
| `-u, --url <url>` | Target URL **(required)** | — |
| `-d, --depth <n>` | Crawl depth | `3` |
| `-t, --threads <n>` | Concurrent requests | `10` |
| `-m, --max-pages <n>` | Max pages to crawl (0 = unlimited) | `0` |
| `-D, --delay <sec>` | Delay between requests | `0` |
| `--rate <n>` | Max requests per second | unlimited |
| `-T, --timeout <sec>` | Request timeout | `15` |
| `-r, --retries <n>` | Retry attempts | `2` |
| `-o, --output <dir>` | Output directory | `<domain>_scrape/` |
| `-v, --verbosity <1-5>` | Verbosity level | `1` |
| `-q, --silent` | Silent mode, only final results | — |
| `--no-color` | Disable colored output | — |
| `--append` | Append to existing output directory | — |

### Network & Auth

| Flag | Description |
|------|-------------|
| `-A, --user-agent <str>` | Custom User-Agent string |
| `-x, --proxy <url>` | Proxy URL (`http://...` or `socks5://...`) |
| `-b, --cookie <str>` | Cookies (`name=val; name2=val2`) |
| `-H, --header <str>` | Extra HTTP header (repeatable) |
| `--auth <user:pass>` | HTTP Basic authentication |
| `--token <token>` | Bearer token |
| `--no-redirect` | Do not follow redirects |

### Scope Control

| Flag | Description |
|------|-------------|
| `-S, --subdomains` | Include subdomains in crawl |
| `-e, --external` | Follow external links |
| `--exclude <regex>` | Exclude URLs matching pattern |
| `--include <regex>` | Only crawl URLs matching pattern |
| `--respect-robots` | Honor robots.txt rules |

### Extraction

| Flag | Description | Default |
|------|-------------|---------|
| `--no-js` | Skip JavaScript extraction | enabled |
| `--no-css` | Skip CSS extraction | enabled |
| `--no-docs` | Skip document/archive extraction | enabled |
| `--no-images` | Skip image extraction | enabled |
| `--emails` | Extract email addresses | disabled |
| `--secrets` | Scan JS for secrets and API keys | disabled |
| `--endpoints` | Extract API endpoints from JS | disabled |
| `--forms` | Extract HTML forms (action + inputs) | disabled |
| `--comments` | Extract HTML comments | disabled |
| `--params` | Extract URL parameters | disabled |
| `--download-js` | Download JavaScript files locally | disabled |
| `--download-css` | Download CSS files locally | disabled |
| `--save-html` | Save raw HTML pages | disabled |

### Passive Sources

| Flag | Description |
|------|-------------|
| `-w, --wayback` | Pull URLs from Wayback Machine |
| `-g, --gau` | Pull URLs via gau |
| `--katana` | Use katana crawler |
| `--gospider` | Use gospider |
| `--hakrawler` | Use hakrawler |
| `--subfinder` | Run subdomain enumeration first |

### Output

| Flag | Description |
|------|-------------|
| `--json` | Write results as `results.json` |

## Examples

**Basic crawl:**
```bash
./scrapper_rapper.sh -u https://example.com
```

**Security-focused scan — secrets, endpoints, emails:**
```bash
./scrapper_rapper.sh -u https://example.com --secrets --endpoints --emails
```

**Deep crawl with passive sources:**
```bash
./scrapper_rapper.sh -u https://example.com -d 5 -t 20 --wayback --gau --katana
```

**Through Burp proxy with Bearer token:**
```bash
./scrapper_rapper.sh -u https://example.com \
  --proxy http://127.0.0.1:8080 \
  --token eyJhbGciOiJIUzI1NiJ9...
```

**Full recon with everything enabled:**
```bash
./scrapper_rapper.sh -u https://example.com \
  -v 3 -d 10 -t 20 \
  --wayback --gau --katana --gospider --hakrawler --subfinder \
  --secrets --endpoints --emails --forms --params --comments \
  --download-js --json
```

**Rate-limited crawl (bug bounty friendly):**
```bash
./scrapper_rapper.sh -u https://example.com \
  --rate 2 --delay 1 -m 100 -d 5
```

**Exclude static assets:**
```bash
./scrapper_rapper.sh -u https://example.com \
  --exclude '\.(png|jpg|gif|woff|svg)$'
```

## Output Structure

Results are saved to `<domain>_scrape/` by default:

```
example.com_scrape/
├── js/
│   ├── jsfiles.txt
│   └── downloaded/        # --download-js
├── css/
│   ├── cssfiles.txt
│   └── downloaded/        # --download-css
├── docs/
│   ├── docs.txt
│   └── archives.txt
├── endpoints/
│   ├── all_urls.txt
│   ├── dynamic.txt
│   ├── wayback.txt        # -w
│   ├── gau.txt            # -g
│   ├── katana.txt
│   ├── gospider.txt
│   ├── hakrawler.txt
│   └── subdomains.txt
├── raw/
│   └── images.txt
├── html/                  # --save-html
├── extra/
│   ├── emails.txt         # --emails
│   ├── secrets.txt        # --secrets
│   ├── api_endpoints.txt  # --endpoints
│   ├── forms.txt          # --forms
│   ├── params.txt         # --params
│   └── comments.txt       # --comments
└── results.json           # --json
```

## Secret Detection

The `--secrets` flag scans JavaScript files for hardcoded credentials using built-in patterns covering:

- AWS Access Key IDs (`AKIA...`)
- Google API keys (`AIza...`)
- GitHub personal access tokens (`ghp_...`)
- Slack tokens (`xox...`)
- JWT tokens
- Bearer tokens
- Generic API keys, secrets, passwords, and auth tokens
- MongoDB and PostgreSQL connection strings

## Disclaimer

This tool is intended for authorized security testing, penetration testing engagements, bug bounty programs, and educational use. Do not use against systems you do not have explicit permission to test.
