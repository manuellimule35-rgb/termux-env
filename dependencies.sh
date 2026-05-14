#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/dependencies.sh — Vérification et gestion des dépendances
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════
#  TABLE DES DÉPENDANCES
#  Format : "nom_commande|nom_paquet_pkg|obligatoire(1/0)|description"
# ═══════════════════════════════════════════════════════════════════════

readonly DEPS_TABLE=(
    # Commande       | Paquet pkg        | Requis | Description
    "git|git|1|Gestion de version"
    "curl|curl|1|Transfert HTTP"
    "wget|wget|1|Téléchargement fichiers"
    "jq|jq|1|Traitement JSON"
    "sqlite3|sqlite|1|Base de données"
    "ssh|openssh|1|Connexions SSH"
    "python|python|1|Langage Python"
    "node|nodejs|0|Langage Node.js"
    "tor|tor|0|Anonymisation réseau"
    "proxychains4|proxychains-ng|0|Proxy chaîning"
    "nmap|nmap|0|Scanner réseau"
    "htop|htop|0|Moniteur processus"
    "tmux|tmux|0|Multiplexeur terminal"
    "fzf|fzf|0|Fuzzy finder"
    "tree|tree|0|Arborescence dossiers"
    "vim|vim|0|Éditeur avancé"
    "nano|nano|1|Éditeur simple"
    "zip|zip|0|Compression ZIP"
    "unzip|unzip|0|Décompression ZIP"
)

# Dépendances critiques par module
declare -A MODULE_DEPS=(
    ["github"]="git curl"
    ["pentest"]="nmap"
    ["tor"]="tor proxychains4"
    ["ssh"]="ssh"
    ["notes"]="sqlite3"
    ["projects"]="sqlite3"
    ["monitoring"]="htop"
    ["network"]="curl nmap"
    ["backup"]="tar zip"
    ["workspace"]=""
    ["scripts"]=""
    ["plugins"]=""
)

# ═══════════════════════════════════════════════════════════════════════
#  VÉRIFICATION D'UNE DÉPENDANCE
# ═══════════════════════════════════════════════════════════════════════

# Retourne 0 si la commande existe
deps_check_cmd() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

# Retourne 0 si le paquet Termux est installé
deps_check_pkg() {
    local pkg="$1"
    pkg list-installed 2>/dev/null | grep -q "^${pkg}/"
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALLER UNE DÉPENDANCE
# ═══════════════════════════════════════════════════════════════════════

deps_install_one() {
    local cmd="$1"
    local pkg="$2"
    local required="$3"

    if deps_check_cmd "$cmd"; then
        ui_success "$cmd déjà disponible ✓"
        return 0
    fi

    ui_info "Installation de $pkg..."
    if pkg install "$pkg" -y >> "${CFG_LOG_ACTIONS:-/dev/null}" 2>&1; then
        ui_success "$pkg installé ✓"
        log_info "Dépendance installée : $pkg" "dependencies"
        return 0
    else
        if [[ "$required" == "1" ]]; then
            ui_error "Échec installation (REQUIS) : $pkg"
            log_error "Échec installation dépendance requise : $pkg" "dependencies"
            return 1
        else
            ui_warning "$pkg non disponible (optionnel)"
            log_warn "Dépendance optionnelle absente : $pkg" "dependencies"
            return 0
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  VÉRIFICATION GLOBALE AU DÉMARRAGE
# ═══════════════════════════════════════════════════════════════════════

# Vérification rapide (sans installation) — utilisé au démarrage de main.sh
deps_check_all_fast() {
    local missing_required=()
    local missing_optional=()

    for entry in "${DEPS_TABLE[@]}"; do
        IFS='|' read -r cmd pkg required desc <<< "$entry"
        if ! deps_check_cmd "$cmd"; then
            if [[ "$required" == "1" ]]; then
                missing_required+=("$pkg")
            else
                missing_optional+=("$pkg")
            fi
        fi
    done

    # Rapport
    if (( ${#missing_required[@]} > 0 )); then
        log_warn "Dépendances requises manquantes : ${missing_required[*]}" "dependencies"
        return 1
    fi

    if (( ${#missing_optional[@]} > 0 )); then
        log_info "Dépendances optionnelles absentes : ${missing_optional[*]}" "dependencies"
    fi

    return 0
}

# Vérification + installation interactive
deps_check_and_install_all() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔍 VÉRIFICATION DES DÉPENDANCES${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    local missing_required=()
    local missing_optional=()
    local ok_count=0

    for entry in "${DEPS_TABLE[@]}"; do
        IFS='|' read -r cmd pkg required desc <<< "$entry"
        if deps_check_cmd "$cmd"; then
            printf "  ${G:-\e[32m}✅${NC:-\e[0m} %-15s ${D:-\e[2;37m}%s${NC:-\e[0m}\n" "$cmd" "$desc"
            (( ok_count++ ))
        else
            if [[ "$required" == "1" ]]; then
                printf "  ${R:-\e[31m}❌${NC:-\e[0m} %-15s ${R:-\e[31m}REQUIS — %s${NC:-\e[0m}\n" "$cmd" "$desc"
                missing_required+=("$cmd|$pkg")
            else
                printf "  ${Y:-\e[33m}⚠️ ${NC:-\e[0m} %-15s ${D:-\e[2;37m}optionnel — %s${NC:-\e[0m}\n" "$cmd" "$desc"
                missing_optional+=("$cmd|$pkg")
            fi
        fi
    done

    echo ""
    printf "  ${B:-\e[34m}OK :${NC:-\e[0m} $ok_count  "
    printf "${R:-\e[31m}Requis manquants :${NC:-\e[0m} ${#missing_required[@]}  "
    printf "${Y:-\e[33m}Optionnels manquants :${NC:-\e[0m} ${#missing_optional[@]}\n\n"

    # Installer les manquants si l'utilisateur le souhaite
    if (( ${#missing_required[@]} + ${#missing_optional[@]} > 0 )); then
        echo -ne "  ${C:-\e[36m}Installer les paquets manquants ? (o/n) : ${NC:-\e[0m}"
        read -r install_confirm

        if [[ "$install_confirm" == "o" || "$install_confirm" == "O" ]]; then
            echo ""
            pkg update -y >> "${CFG_LOG_ACTIONS:-/dev/null}" 2>&1 || true

            for entry in "${missing_required[@]}"; do
                IFS='|' read -r cmd pkg <<< "$entry"
                deps_install_one "$cmd" "$pkg" "1"
            done

            for entry in "${missing_optional[@]}"; do
                IFS='|' read -r cmd pkg <<< "$entry"
                deps_install_one "$cmd" "$pkg" "0"
            done

            printf "\n${G:-\e[32m}  ✅ Installation terminée.${NC:-\e[0m}\n"
            log_info "Installation dépendances manquantes terminée" "dependencies"
        fi
    else
        printf "  ${G:-\e[32m}✅ Toutes les dépendances sont satisfaites !${NC:-\e[0m}\n"
    fi

    echo ""
    read -rp "  Entrée pour continuer..."
}

# ═══════════════════════════════════════════════════════════════════════
#  VÉRIFICATION PAR MODULE
# ═══════════════════════════════════════════════════════════════════════

# Vérifier les dépendances d'un module avant de le lancer
# Usage : deps_check_module "github" || return 1
deps_check_module() {
    local module="$1"
    local required_cmds="${MODULE_DEPS[$module]:-}"

    [[ -z "$required_cmds" ]] && return 0

    local missing=()
    for cmd in $required_cmds; do
        if ! deps_check_cmd "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        printf "\n${Y:-\e[33m}  ⚠️  Module '%s' : dépendances manquantes :${NC:-\e[0m}\n" "$module"
        for m in "${missing[@]}"; do
            printf "  ${R:-\e[31m}  → %s${NC:-\e[0m}\n" "$m"
        done
        printf "\n  ${D:-\e[2;37m}Lance [i] depuis le menu pour installer.${NC:-\e[0m}\n\n"
        log_warn "Module $module : dépendances manquantes : ${missing[*]}" "dependencies"
        read -rp "  Entrée..."
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALLATEUR INTÉGRÉ (menu [i] du dashboard)
# ═══════════════════════════════════════════════════════════════════════

# Table de correspondance alias → vrai nom paquet
declare -A PKG_ALIAS_MAP=(
    ["hydra"]="thc-hydra"
    ["thc-hydra"]="thc-hydra"
    ["john"]="john-the-ripper"
    ["hashcat"]="hashcat"
    ["aircrack"]="aircrack-ng"
    ["aircrack-ng"]="aircrack-ng"
    ["metasploit"]="metasploit"
    ["nmap"]="nmap"
    ["masscan"]="masscan"
    ["netcat"]="netcat-openbsd"
    ["nc"]="netcat-openbsd"
    ["whois"]="whois"
    ["sqlmap"]="sqlmap"
    ["curl"]="curl"
    ["wget"]="wget"
    ["python"]="python"
    ["python3"]="python"
    ["node"]="nodejs"
    ["nodejs"]="nodejs"
    ["ruby"]="ruby"
    ["golang"]="golang"
    ["go"]="golang"
    ["rust"]="rust"
    ["php"]="php"
    ["nano"]="nano"
    ["vim"]="vim"
    ["neovim"]="neovim"
    ["nvim"]="neovim"
    ["git"]="git"
    ["htop"]="htop"
    ["tmux"]="tmux"
    ["tree"]="tree"
    ["zip"]="zip"
    ["unzip"]="unzip"
    ["jq"]="jq"
    ["fzf"]="fzf"
    ["bat"]="bat"
    ["ripgrep"]="ripgrep"
    ["rg"]="ripgrep"
    ["openssh"]="openssh"
    ["ssh"]="openssh"
    ["tor"]="tor"
    ["proxychains"]="proxychains-ng"
    ["sqlite"]="sqlite"
    ["sqlite3"]="sqlite"
    ["cmatrix"]="cmatrix"
    ["gum"]="gum"
    ["shellcheck"]="shellcheck"
)

deps_installer_menu() {
    while true; do
        clear
        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📦 INSTALLATEUR INTÉGRÉ${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Installer un paquet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Vérifier toutes les dépendances\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Mettre à jour tous les paquets\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"
        read -r choice

        case "$choice" in
            1) _deps_install_one_interactive ;;
            2) deps_check_and_install_all ;;
            3) _deps_update_all ;;
            0|"") return 0 ;;
        esac
    done
}

# Installer un paquet interactivement
_deps_install_one_interactive() {
    clear
    printf "${C:-\e[36m}  ╔════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}  ║${NC:-\e[0m}  ${Y:-\e[33m}Installation d'un paquet${NC:-\e[0m}\n"
    printf "${C:-\e[36m}  ╚════════════════════════════════════════╝${NC:-\e[0m}\n\n"
    printf "  ${D:-\e[2;37m}Exemples : nmap, hydra, python, vim, tor...${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}Nom du paquet : ${NC:-\e[0m}"
    read -r user_input

    [[ -z "$user_input" ]] && return

    # Résoudre l'alias
    local real_pkg="${PKG_ALIAS_MAP[$user_input]:-$user_input}"

    printf "\n  ${B:-\e[34m}Paquet demandé :${NC:-\e[0m} %s\n" "$user_input"
    [[ "$real_pkg" != "$user_input" ]] && \
        printf "  ${G:-\e[32m}Paquet réel    :${NC:-\e[0m} %s\n" "$real_pkg"

    echo ""
    echo -ne "  ${C:-\e[36m}Lancer l'installation de '${W:-\e[1;37m}${real_pkg}${NC:-\e[0m}${C:-\e[36m}' ? (o/n) : ${NC:-\e[0m}"
    read -r confirm

    [[ "$confirm" != "o" && "$confirm" != "O" ]] && \
        printf "${Y:-\e[33m}  Annulé.${NC:-\e[0m}\n" && sleep 1 && return

    echo ""
    log_info "Installation manuelle : $real_pkg" "dependencies"
    pkg install "$real_pkg" -y

    local exit_code=$?
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        printf "${G:-\e[32m}  ✅ '$real_pkg' installé avec succès !${NC:-\e[0m}\n\n"
        log_info "Installé avec succès : $real_pkg" "dependencies"
    else
        printf "${R:-\e[31m}  ❌ Erreur installation '%s'.${NC:-\e[0m}\n" "$real_pkg"
        printf "${D:-\e[2;37m}  Vérifie le nom du paquet et ta connexion.${NC:-\e[0m}\n\n"
        log_error "Échec installation : $real_pkg" "dependencies"
    fi
    read -rp "  Entrée pour revenir..."
}

# Mettre à jour tous les paquets Termux
_deps_update_all() {
    clear
    printf "${C:-\e[36m}  Mise à jour de tous les paquets Termux...${NC:-\e[0m}\n\n"
    log_info "Mise à jour globale paquets" "dependencies"
    pkg update -y && pkg upgrade -y
    printf "\n${G:-\e[32m}  ✅ Mise à jour terminée.${NC:-\e[0m}\n\n"
    log_info "Mise à jour globale terminée" "dependencies"
    read -rp "  Entrée..."
}
