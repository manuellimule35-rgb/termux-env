#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/security.sh — Sécurité : validation, protection, logs
# Dépend de : core/config.sh, core/logger.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# ═══════════════════════════════════════════════════════════════════════
#  VALIDATION DES ENTRÉES UTILISATEUR
# ═══════════════════════════════════════════════════════════════════════

# Vérifier qu'une chaîne ne contient pas de caractères dangereux shell
sec_safe_string() {
    local input="$1"
    local label="${2:-Entrée}"

    # Caractères interdits : ; & | ` $ ( ) { } < > ! \ newline
    if [[ "$input" =~ [';''&''|''`''$''('')''{''}''<''>'!'\\'] ]]; then
        log_security "Entrée dangereuse détectée pour '$label' : $input" "security"
        ui_error "Caractères non autorisés dans : $label"
        return 1
    fi
    return 0
}

# Vérifier qu'un chemin ne contient pas de traversée de répertoire
sec_safe_path() {
    local path="$1"

    # Interdire ../  et chemins absolus hors HOME
    if [[ "$path" == *".."* ]]; then
        log_security "Traversée de répertoire détectée : $path" "security"
        ui_error "Chemin non autorisé : $path"
        return 1
    fi

    # Interdire les chemins système critiques
    local forbidden_paths=("/etc" "/system" "/proc" "/sys" "/dev" "/bin" "/sbin")
    for fp in "${forbidden_paths[@]}"; do
        if [[ "$path" == "$fp"* ]]; then
            log_security "Accès chemin système interdit : $path" "security"
            ui_error "Accès interdit : $path"
            return 1
        fi
    done

    return 0
}

# Vérifier qu'une commande n'est pas dangereuse
sec_safe_command() {
    local cmd="$1"

    # Commandes dangereuses interdites
    local forbidden_cmds=(
        "rm -rf /"
        "rm -rf ~"
        "rm -rf \$HOME"
        "mkfs"
        "dd if=/dev/zero"
        "chmod -R 777 /"
        ":(){ :|:& };:"   # fork bomb
    )

    for fc in "${forbidden_cmds[@]}"; do
        if [[ "$cmd" == *"$fc"* ]]; then
            log_security "Commande dangereuse bloquée : $cmd" "security"
            ui_error "Commande non autorisée."
            return 1
        fi
    done

    return 0
}

# Valider un nom de projet / alias (alphanumérique + tirets)
sec_validate_name() {
    local name="$1"
    local label="${2:-Nom}"
    local max_len="${3:-64}"

    if [[ -z "${name// }" ]]; then
        ui_error "$label ne peut pas être vide."
        return 1
    fi

    if (( ${#name} > max_len )); then
        ui_error "$label trop long (max $max_len caractères)."
        return 1
    fi

    if ! [[ "$name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        ui_error "$label contient des caractères invalides (autorisés : a-z A-Z 0-9 _ . -)."
        return 1
    fi

    return 0
}

# Valider une URL GitHub
sec_validate_github_url() {
    local url="$1"

    if ! [[ "$url" =~ ^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+(\.git)?$ ]]; then
        ui_error "URL GitHub invalide. Format attendu : https://github.com/user/repo"
        log_security "URL GitHub invalide : $url" "security"
        return 1
    fi

    return 0
}

# Valider une adresse SSH host (IP ou hostname)
sec_validate_ssh_host() {
    local host="$1"

    # Hostname ou IP valide
    if ! [[ "$host" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        ui_error "Adresse SSH invalide : $host"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  PROTECTION RM -RF
# ═══════════════════════════════════════════════════════════════════════

# Supprimer un fichier/dossier de façon sécurisée
# — refuse de supprimer hors de $HOME/mon_env ou $HOME/github_projects
sec_safe_remove() {
    local target="$1"
    local force="${2:-false}"

    # Résoudre le chemin réel
    local real_target
    real_target=$(realpath "$target" 2>/dev/null || echo "$target")

    # Vérifier que la cible est dans un dossier autorisé
    local allowed_roots=(
        "${CFG_INSTALL_DIR:-$HOME/mon_env}"
        "${CFG_GITHUB_DIR:-$HOME/mon_env/github_projects}"
        "$HOME/tmp"
    )

    local allowed=false
    for root in "${allowed_roots[@]}"; do
        if [[ "$real_target" == "$root"* ]]; then
            allowed=true
            break
        fi
    done

    if [[ "$allowed" == "false" ]]; then
        log_security "Suppression refusée hors zone autorisée : $real_target" "security"
        ui_error "Suppression non autorisée : $real_target"
        return 1
    fi

    # Double confirmation pour les dossiers
    if [[ -d "$real_target" && "$force" != "true" ]]; then
        echo -ne "  ${R:-\e[31m}Supprimer le dossier '${real_target/$HOME/~}' ? (tape SUPPRIMER) : ${NC:-\e[0m}"
        read -r confirm
        if [[ "$confirm" != "SUPPRIMER" ]]; then
            printf "${Y:-\e[33m}  Suppression annulée.${NC:-\e[0m}\n"
            return 1
        fi
    fi

    rm -rf "$real_target"
    log_security "Suppression effectuée : $real_target" "security"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  VÉRIFICATION DES PERMISSIONS
# ═══════════════════════════════════════════════════════════════════════

# Vérifier que les scripts core sont bien protégés
sec_check_permissions() {
    local issues=0

    # Vérifier que database/ n'est pas lisible par tous
    if [[ -d "${CFG_DATABASE_DIR:-$HOME/mon_env/database}" ]]; then
        local perms
        perms=$(stat -c "%a" "${CFG_DATABASE_DIR:-$HOME/mon_env/database}" 2>/dev/null || echo "777")
        if [[ "$perms" != "700" && "$perms" != "750" ]]; then
            log_security "Permissions database/ incorrectes : $perms" "security"
            chmod 700 "${CFG_DATABASE_DIR:-$HOME/mon_env/database}" 2>/dev/null || true
            (( issues++ ))
        fi
    fi

    # Vérifier que configs/ est protégé
    if [[ -d "${CFG_CONFIGS_DIR:-$HOME/mon_env/configs}" ]]; then
        local perms
        perms=$(stat -c "%a" "${CFG_CONFIGS_DIR:-$HOME/mon_env/configs}" 2>/dev/null || echo "777")
        if [[ "$perms" != "700" && "$perms" != "750" ]]; then
            chmod 700 "${CFG_CONFIGS_DIR:-$HOME/mon_env/configs}" 2>/dev/null || true
            (( issues++ ))
        fi
    fi

    if (( issues > 0 )); then
        log_security "Permissions corrigées automatiquement ($issues)" "security"
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  AVERTISSEMENT PENTEST
# ═══════════════════════════════════════════════════════════════════════

# Afficher l'avertissement légal avant le module pentest
sec_pentest_disclaimer() {
    clear
    printf "${R:-\e[31m}"
    printf "╔══════════════════════════════════════════════════════════════╗\n"
    printf "║              ⚠️   AVERTISSEMENT LÉGAL ⚠️                    ║\n"
    printf "╠══════════════════════════════════════════════════════════════╣\n"
    printf "${NC:-\e[0m}${R:-\e[31m}║${NC:-\e[0m}  Les outils de ce module sont UNIQUEMENT pour :             ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}    • Apprentissage et formation personnelle                ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}    • Tests sur des systèmes que vous possédez              ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}    • Environnements de laboratoire isolés                  ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}    • Programmes bug bounty avec autorisation écrite         ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}                                                            ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}  L'utilisation sur des systèmes SANS AUTORISATION est      ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}║${NC:-\e[0m}  ILLÉGALE et peut entraîner des poursuites pénales.        ${R:-\e[31m}║${NC:-\e[0m}\n"
    printf "${R:-\e[31m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    echo -ne "  ${Y:-\e[33m}J'accepte et je comprends (tape OUI) : ${NC:-\e[0m}"
    read -r accept

    if [[ "$accept" != "OUI" ]]; then
        printf "\n${G:-\e[32m}  Accès refusé. Retour au menu.${NC:-\e[0m}\n\n"
        log_security "Accès module pentest refusé (disclaimer non accepté)" "security"
        sleep 1
        return 1
    fi

    log_security "Accès module pentest accepté (disclaimer validé)" "security"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════
#  RAPPORT SÉCURITÉ
# ═══════════════════════════════════════════════════════════════════════

sec_report() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔒 RAPPORT DE SÉCURITÉ${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    # Derniers événements sécurité
    local sec_log="${CFG_LOG_SECURITY:-$HOME/mon_env/logs/security.log}"
    if [[ -f "$sec_log" && -s "$sec_log" ]]; then
        printf "  ${R:-\e[31m}Derniers événements sécurité :${NC:-\e[0m}\n\n"
        tail -20 "$sec_log" | while IFS= read -r line; do
            printf "  ${D:-\e[2;37m}%s${NC:-\e[0m}\n" "$line"
        done
    else
        printf "  ${G:-\e[32m}Aucun événement de sécurité enregistré.${NC:-\e[0m}\n"
    fi

    echo ""
    # Vérification permissions
    printf "  ${B:-\e[34m}Vérification des permissions...${NC:-\e[0m}\n"
    sec_check_permissions && printf "  ${G:-\e[32m}✅ Permissions OK${NC:-\e[0m}\n"

    echo ""
    read -rp "  Entrée pour revenir..."
}
