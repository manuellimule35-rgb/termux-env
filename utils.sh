#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/utils.sh — Fonctions utilitaires partagées par tous les modules
# Dépend de : core/config.sh, core/logger.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════
#  VALIDATION DES ENTRÉES
# ═══════════════════════════════════════════════════════════════════════

# Vérifie qu'une valeur n'est pas vide
utils_not_empty() {
    local value="$1"
    local label="${2:-Valeur}"
    if [[ -z "${value// }" ]]; then
        ui_error "$label ne peut pas être vide."
        return 1
    fi
}

# Vérifie format alphanumérique (+ tirets/underscores autorisés)
utils_is_alnum() {
    local value="$1"
    [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# Vérifie format URL basique
utils_is_url() {
    local url="$1"
    [[ "$url" =~ ^https?://[a-zA-Z0-9._/-]+ ]]
}

# Vérifie qu'un port est valide (1-65535)
utils_is_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}

# Vérifie qu'une adresse IP est valide
utils_is_ip() {
    local ip="$1"
    local pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ "$ip" =~ $pattern ]]; then
        IFS='.' read -ra parts <<< "$ip"
        for part in "${parts[@]}"; do
            (( part <= 255 )) || return 1
        done
        return 0
    fi
    return 1
}

# Sanitize une chaîne — supprime les caractères dangereux
utils_sanitize() {
    local input="$1"
    echo "$input" | tr -cd '[:alnum:][:space:]._@:/-'
}

# ═══════════════════════════════════════════════════════════════════════
#  SYSTÈME DE FICHIERS
# ═══════════════════════════════════════════════════════════════════════

# Créer un dossier de façon sécurisée
utils_mkdir() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        log_error "utils_mkdir: chemin vide" "utils"
        return 1
    fi
    mkdir -p "$dir" 2>/dev/null || {
        log_error "Impossible de créer : $dir" "utils"
        return 1
    }
}

# Vérifier qu'un fichier existe et est lisible
utils_file_exists() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Vérifier qu'un dossier existe
utils_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

# Horodatage compact pour noms de fichiers
utils_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# Horodatage lisible
utils_timestamp_human() {
    date '+%d/%m/%Y %H:%M:%S'
}

# Taille d'un fichier en octets
utils_file_size() {
    local file="$1"
    [[ -f "$file" ]] && stat -c%s "$file" 2>/dev/null || echo 0
}

# ═══════════════════════════════════════════════════════════════════════
#  RÉSEAU
# ═══════════════════════════════════════════════════════════════════════

# Vérifie la connexion internet
utils_check_internet() {
    curl -s --max-time 5 https://google.com > /dev/null 2>&1
}

# IP publique
utils_get_public_ip() {
    curl -s --max-time 4 https://api.ipify.org 2>/dev/null || echo "offline"
}

# IP locale
utils_get_local_ip() {
    local ip
    ip=$(ip -4 addr show 2>/dev/null \
         | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
         | grep -v '^127\.' | head -1 || echo "")
    [[ -z "$ip" ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "?")
    echo "${ip:-?}"
}

# Vérifier si un port local est ouvert
utils_port_open() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep -q ":${port}\b"
}

# ═══════════════════════════════════════════════════════════════════════
#  COMMANDES & PAQUETS
# ═══════════════════════════════════════════════════════════════════════

# Vérifier qu'une commande existe
utils_cmd_exists() {
    command -v "$1" &>/dev/null
}

# Vérifier qu'un paquet Termux est installé
utils_pkg_installed() {
    pkg list-installed 2>/dev/null | grep -q "^${1}/"
}

# Installer un paquet si absent
utils_ensure_pkg() {
    local pkg="$1"
    if ! utils_pkg_installed "$pkg"; then
        log_info "Installation automatique : $pkg" "utils"
        pkg install "$pkg" -y >> "${CFG_LOG_ACTIONS:-/dev/null}" 2>&1 || {
            log_warn "Échec installation : $pkg" "utils"
            return 1
        }
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  SYSTÈME ANDROID / TERMUX
# ═══════════════════════════════════════════════════════════════════════

# Niveau de batterie
utils_get_battery() {
    local bat_path
    bat_path=$(ls /sys/class/power_supply/battery/capacity \
               /sys/class/power_supply/Battery/capacity 2>/dev/null | head -1 || echo "")
    if [[ -n "$bat_path" && -f "$bat_path" ]]; then
        echo "$(cat "$bat_path" 2>/dev/null || echo "?")%"
    else
        local pct
        pct=$(termux-battery-status 2>/dev/null \
              | grep -oP '"percentage":\s*\K\d+' || echo "")
        [[ -n "$pct" ]] && echo "${pct}%" || echo "N/A"
    fi
}

# Modèle d'appareil
utils_get_device_model() {
    getprop ro.product.model 2>/dev/null || echo "Termux Device"
}

# Version Android
utils_get_android_version() {
    getprop ro.build.version.release 2>/dev/null || echo "?"
}

# RAM utilisée / totale
utils_get_ram() {
    local used total
    used=$(free -m 2>/dev/null | awk 'NR==2{print $3}' || echo "?")
    total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "?")
    echo "${used}MB / ${total}MB"
}

# Espace disque HOME
utils_get_storage() {
    df -h "$HOME" 2>/dev/null \
        | awk 'NR==2{print $3"/"$2" ("$5" utilisé)"}' || echo "?"
}

# Uptime
utils_get_uptime() {
    uptime -p 2>/dev/null | sed 's/up //' || echo "?"
}

# Température CPU
utils_get_temp() {
    local temp_path="/sys/class/thermal/thermal_zone0/temp"
    if [[ -f "$temp_path" ]]; then
        local raw
        raw=$(cat "$temp_path" 2>/dev/null || echo "0")
        printf "%.1f°C" "$(echo "scale=1; $raw / 1000" | bc 2>/dev/null || echo "?")"
    else
        echo "N/A"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  DÉTECTION DE LANGAGE (projets GitHub / locaux)
# ═══════════════════════════════════════════════════════════════════════

# Détecter le langage principal d'un projet
utils_detect_language() {
    local project_dir="$1"

    [[ ! -d "$project_dir" ]] && echo "unknown" && return

    if   [[ -f "$project_dir/package.json" ]];           then echo "nodejs"
    elif [[ -f "$project_dir/requirements.txt" ]] ||
         [[ -f "$project_dir/setup.py" ]] ||
         [[ -f "$project_dir/pyproject.toml" ]];         then echo "python"
    elif [[ -f "$project_dir/Cargo.toml" ]];             then echo "rust"
    elif [[ -f "$project_dir/go.mod" ]];                 then echo "golang"
    elif [[ -f "$project_dir/pom.xml" ]] ||
         [[ -f "$project_dir/build.gradle" ]];           then echo "java"
    elif [[ -f "$project_dir/Gemfile" ]];                then echo "ruby"
    elif [[ -f "$project_dir/composer.json" ]];          then echo "php"
    elif find "$project_dir" -maxdepth 2 -name "*.sh" \
         2>/dev/null | grep -q .;                        then echo "bash"
    else                                                      echo "unknown"
    fi
}

# Commande de lancement par défaut selon le langage
utils_get_run_cmd() {
    local lang="$1"
    local project_dir="${2:-}"

    case "$lang" in
        nodejs)
            if [[ -f "$project_dir/package.json" ]] && utils_cmd_exists jq; then
                local start
                start=$(jq -r '.scripts.start // empty' \
                        "$project_dir/package.json" 2>/dev/null || echo "")
                [[ -n "$start" ]] && echo "npm start" || echo "node index.js"
            else
                echo "node index.js"
            fi
            ;;
        python)  echo "python main.py" ;;
        rust)    echo "cargo run"      ;;
        golang)  echo "go run ."       ;;
        ruby)    echo "ruby main.rb"   ;;
        php)     echo "php index.php"  ;;
        bash)    echo "bash main.sh"   ;;
        *)       echo ""               ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  DIVERS
# ═══════════════════════════════════════════════════════════════════════

# Tronquer une chaîne à N caractères
utils_truncate() {
    local str="$1"
    local max="${2:-50}"
    if (( ${#str} > max )); then
        echo "${str:0:$((max-3))}..."
    else
        echo "$str"
    fi
}

# Centrer un texte dans une largeur donnée
utils_center() {
    local text="$1"
    local width="${2:-62}"
    local len=${#text}
    local pad=$(( (width - len) / 2 ))
    printf "%*s%s\n" "$pad" "" "$text"
}

# Pause avec message
utils_pause() {
    local msg="${1:-Entrée pour continuer...}"
    echo -ne "\n  ${Y:-\e[33m}${msg}${NC:-\e[0m}"
    read -r
}

# Copier dans le presse-papier Termux
utils_clipboard_copy() {
    local content="$1"
    if utils_cmd_exists termux-clipboard-set; then
        echo "$content" | termux-clipboard-set
        return 0
    fi
    return 1
}

# Ouvrir une URL dans le navigateur Android
utils_open_url() {
    local url="$1"
    if utils_cmd_exists termux-open-url; then
        termux-open-url "$url" &
    else
        log_warn "termux-open-url non disponible" "utils"
    fi
}

# Notification Android
utils_notify() {
    local title="$1"
    local message="$2"
    if utils_cmd_exists termux-notification; then
        termux-notification \
            --title "$title" \
            --content "$message" \
            --id "cyber_dashboard" \
            &>/dev/null &
    fi
}

# Générer un identifiant unique court (8 chars)
utils_gen_id() {
    tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 8 || \
    date +%s | sha256sum 2>/dev/null | head -c 8 || \
    echo "$(date +%s)"
}
