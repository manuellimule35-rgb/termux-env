#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/plugins.sh — Système de plugins : chargement, gestion, exemple
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh, core/utils.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly PLUGINS_DIR="${CFG_PLUGINS_DIR:-$HOME/mon_env/plugins}"

# ═══════════════════════════════════════════════════════════════════════
#  SCANNER LES PLUGINS DISPONIBLES
# ═══════════════════════════════════════════════════════════════════════

_plg_scan() {
    local plugins=()
    while IFS= read -r -d '' file; do
        plugins+=("$file")
    done < <(find "$PLUGINS_DIR" -maxdepth 2 -name "*.plugin.sh" -print0 2>/dev/null)
    echo "${plugins[@]:-}"
}

# ─── Lire les métadonnées d'un plugin ─────────────────────────────────
_plg_meta() {
    local file="$1"
    local field="$2"   # PLUGIN_NAME | PLUGIN_VERSION | PLUGIN_DESCRIPTION | PLUGIN_AUTHOR
    grep "^# ${field}=" "$file" 2>/dev/null | cut -d'"' -f2 || echo ""
}

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES PLUGINS
# ═══════════════════════════════════════════════════════════════════════

_plg_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔌 PLUGINS${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local count=0
    while IFS= read -r -d '' file; do
        local name version desc
        name=$(_plg_meta "$file" "PLUGIN_NAME")
        version=$(_plg_meta "$file" "PLUGIN_VERSION")
        desc=$(_plg_meta "$file" "PLUGIN_DESCRIPTION")
        name="${name:-$(basename "$file" .plugin.sh)}"

        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}●${NC:-\e[0m} %-20s ${D:-\e[2;37m}v%-6s${NC:-\e[0m} %s\n" \
            "$name" "${version:-?}" \
            "$(utils_truncate "${desc:-}" 28)"
        (( count++ ))
    done < <(find "$PLUGINS_DIR" -maxdepth 2 -name "*.plugin.sh" -print0 2>/dev/null)

    if (( count == 0 )); then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun plugin installé.${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Dossier : %s${NC:-\e[0m}\n" \
            "${PLUGINS_DIR/$HOME/~}"
    fi

    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%d plugin(s) installé(s)${NC:-\e[0m}\n" "$count"
    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  CHARGER ET EXÉCUTER UN PLUGIN
# ═══════════════════════════════════════════════════════════════════════

_plg_run() {
    _plg_list

    echo -ne "  ${C:-\e[36m}Nom du plugin à lancer : ${NC:-\e[0m}"; read -r plugin_name
    [[ -z "$plugin_name" ]] && return
    sec_validate_name "$plugin_name" "Plugin" 2>/dev/null || return 1

    # Chercher le fichier
    local plugin_file=""
    while IFS= read -r -d '' file; do
        local file_name
        file_name=$(basename "$file" .plugin.sh)
        local meta_name
        meta_name=$(_plg_meta "$file" "PLUGIN_NAME")
        if [[ "$file_name" == "$plugin_name" || "$meta_name" == "$plugin_name" ]]; then
            plugin_file="$file"
            break
        fi
    done < <(find "$PLUGINS_DIR" -name "*.plugin.sh" -print0 2>/dev/null)

    if [[ -z "$plugin_file" ]]; then
        ui_error "Plugin '$plugin_name' introuvable."
        sleep 2; return 1
    fi

    printf "\n  ${Y:-\e[33m}Chargement du plugin : %s${NC:-\e[0m}\n\n" "$plugin_name"
    log_action "Plugin lancé : $plugin_name" "plugins"

    # Charger le plugin dans un sous-shell pour isolation
    (
        # shellcheck source=/dev/null
        source "$plugin_file"

        # Chercher une fonction menu ou main dans le plugin
        if declare -f plugin_menu &>/dev/null; then
            plugin_menu
        elif declare -f plugin_run &>/dev/null; then
            plugin_run
        elif declare -f plugin_main &>/dev/null; then
            plugin_main
        else
            printf "  ${Y:-\e[33m}Plugin chargé mais aucune fonction 'plugin_menu/run/main' trouvée.${NC:-\e[0m}\n"
            printf "  ${D:-\e[2;37m}Fonctions disponibles :${NC:-\e[0m}\n"
            declare -F | awk '{print "  " $3}'
        fi
    )

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  INSTALLER UN PLUGIN (depuis URL)
# ═══════════════════════════════════════════════════════════════════════

_plg_install_url() {
    clear
    ui_box_title "📥 INSTALLER UN PLUGIN DEPUIS UNE URL"

    printf "  ${D:-\e[2;37m}Le fichier doit être un script .plugin.sh valide.${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}URL du plugin (.plugin.sh) : ${NC:-\e[0m}"; read -r url
    [[ -z "$url" ]] && return
    utils_is_url "$url" || { ui_error "URL invalide."; sleep 2; return 1; }

    utils_check_internet || { ui_error "Pas de connexion."; sleep 2; return 1; }

    local filename
    filename=$(basename "$url")
    [[ "$filename" == *.plugin.sh ]] || filename="${filename%.sh}.plugin.sh"
    sec_validate_name "${filename%.plugin.sh}" "Plugin" 2>/dev/null || return 1

    local dest="$PLUGINS_DIR/$filename"
    mkdir -p "$PLUGINS_DIR"

    printf "\n  ${Y:-\e[33m}Téléchargement de %s...${NC:-\e[0m}\n" "$filename"

    if curl -fsSL -o "$dest" "$url" 2>/dev/null || \
       wget -q -O "$dest" "$url" 2>/dev/null; then
        # Vérification minimale : doit contenir #!/bin/bash
        if grep -q "#!/" "$dest" 2>/dev/null; then
            chmod +x "$dest"
            local name
            name=$(_plg_meta "$dest" "PLUGIN_NAME")
            name="${name:-$filename}"
            ui_success "Plugin '$name' installé : ${dest/$HOME/~}"
            log_action "Plugin installé : $filename" "plugins"
        else
            rm -f "$dest"
            ui_error "Fichier invalide — pas un script shell."
        fi
    else
        rm -f "$dest" 2>/dev/null || true
        ui_error "Téléchargement échoué."
    fi
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  CRÉER UN PLUGIN (template)
# ═══════════════════════════════════════════════════════════════════════

_plg_create() {
    clear
    ui_box_title "✨ CRÉER UN PLUGIN"

    echo -ne "  ${C:-\e[36m}Nom du plugin (ex: mon-outil) : ${NC:-\e[0m}"; read -r plg_name
    [[ -z "$plg_name" ]] && return
    sec_validate_name "$plg_name" "Nom" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Version (défaut: 1.0) : ${NC:-\e[0m}"; read -r plg_version
    plg_version="${plg_version:-1.0}"

    echo -ne "  ${C:-\e[36m}Description : ${NC:-\e[0m}"; read -r plg_desc
    echo -ne "  ${C:-\e[36m}Auteur : ${NC:-\e[0m}"; read -r plg_author

    local dest="$PLUGINS_DIR/${plg_name}.plugin.sh"
    mkdir -p "$PLUGINS_DIR"

    if [[ -f "$dest" ]]; then
        ui_warning "Plugin '$plg_name' existe déjà."
        echo -ne "  ${Y:-\e[33m}Écraser ? (o/n) : ${NC:-\e[0m}"; read -r ow
        [[ "${ow,,}" != "o" ]] && return
    fi

    cat > "$dest" << TEMPLATE
#!/data/data/com.termux/files/usr/bin/bash
# ══════════════════════════════════════════════════════════════════════
# PLUGIN_NAME="${plg_name}"
# PLUGIN_VERSION="${plg_version}"
# PLUGIN_DESCRIPTION="${plg_desc:-Mon plugin}"
# PLUGIN_AUTHOR="${plg_author:-Shadow}"
# PLUGIN_DATE="$(date '+%d/%m/%Y')"
#
# Structure obligatoire :
#   - Métadonnées en commentaires (lignes PLUGIN_*)
#   - Fonction plugin_menu() OU plugin_run() OU plugin_main()
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail

# ─── Variables du plugin ─────────────────────────────────────────────
readonly PLG_NAME="${plg_name}"
readonly PLG_VERSION="${plg_version}"

# ─── Fonctions internes ───────────────────────────────────────────────
_${plg_name//-/_}_run() {
    printf "\${C:-\e[36m}Plugin : %s v%s\${NC:-\e[0m}\n" "\$PLG_NAME" "\$PLG_VERSION"
    printf "\${D:-\e[2;37m}Modifie ce fichier pour ajouter ta logique.\${NC:-\e[0m}\n\n"
    echo "Hello depuis le plugin \$PLG_NAME !"
}

# ─── Point d'entrée (requis) ─────────────────────────────────────────
plugin_menu() {
    clear
    printf "\${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗\${NC:-\e[0m}\n"
    printf "\${C:-\e[36m}║\${NC:-\e[0m}  🔌 Plugin : %s v%s\n" "\$PLG_NAME" "\$PLG_VERSION"
    printf "\${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝\${NC:-\e[0m}\n\n"

    printf "  \${G:-\e[32m}[1]\${NC:-\e[0m} Lancer\n"
    printf "  \${G:-\e[32m}[0]\${NC:-\e[0m} Quitter\n\n"
    echo -ne "  Choix : "; read -r choice

    case "\$choice" in
        1) _${plg_name//-/_}_run ;;
        0|"") return 0 ;;
    esac
}
TEMPLATE

    chmod +x "$dest"
    ui_success "Plugin créé : ${dest/$HOME/~}"
    log_action "Plugin créé : $plg_name" "plugins"

    echo -ne "  ${C:-\e[36m}Ouvrir dans nano pour éditer ? (o/n) : ${NC:-\e[0m}"
    read -r edit_now
    [[ "${edit_now,,}" == "o" ]] && utils_cmd_exists nano && nano "$dest"
    sleep 1
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN PLUGIN
# ═══════════════════════════════════════════════════════════════════════

_plg_delete() {
    _plg_list

    echo -ne "  ${C:-\e[36m}Nom du plugin à supprimer : ${NC:-\e[0m}"; read -r plg_name
    [[ -z "$plg_name" ]] && return

    local plugin_file=""
    while IFS= read -r -d '' file; do
        local file_base
        file_base=$(basename "$file" .plugin.sh)
        [[ "$file_base" == "$plg_name" ]] && plugin_file="$file" && break
    done < <(find "$PLUGINS_DIR" -name "*.plugin.sh" -print0 2>/dev/null)

    [[ -z "$plugin_file" ]] && { ui_error "Plugin introuvable."; sleep 2; return 1; }

    printf "  ${Y:-\e[33m}Supprimer le plugin '%s' ? (o/n) : ${NC:-\e[0m}" "$plg_name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    sec_safe_remove "$plugin_file" "true" 2>/dev/null && {
        ui_success "Plugin '$plg_name' supprimé."
        log_action "Plugin supprimé : $plg_name" "plugins"
    }
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  AFFICHER LES DÉTAILS D'UN PLUGIN
# ═══════════════════════════════════════════════════════════════════════

_plg_info() {
    _plg_list

    echo -ne "  ${C:-\e[36m}Nom du plugin : ${NC:-\e[0m}"; read -r plg_name
    [[ -z "$plg_name" ]] && return

    local plugin_file=""
    while IFS= read -r -d '' file; do
        [[ "$(basename "$file" .plugin.sh)" == "$plg_name" ]] && \
            plugin_file="$file" && break
    done < <(find "$PLUGINS_DIR" -name "*.plugin.sh" -print0 2>/dev/null)

    [[ -z "$plugin_file" ]] && { ui_error "Plugin introuvable."; sleep 2; return 1; }

    clear
    ui_box_title "🔌 DÉTAILS PLUGIN — $plg_name"

    printf "  ${B:-\e[34m}Nom         :${NC:-\e[0m} %s\n" "$(_plg_meta "$plugin_file" "PLUGIN_NAME")"
    printf "  ${B:-\e[34m}Version     :${NC:-\e[0m} %s\n" "$(_plg_meta "$plugin_file" "PLUGIN_VERSION")"
    printf "  ${B:-\e[34m}Description :${NC:-\e[0m} %s\n" "$(_plg_meta "$plugin_file" "PLUGIN_DESCRIPTION")"
    printf "  ${B:-\e[34m}Auteur      :${NC:-\e[0m} %s\n" "$(_plg_meta "$plugin_file" "PLUGIN_AUTHOR")"
    printf "  ${B:-\e[34m}Date        :${NC:-\e[0m} %s\n" "$(_plg_meta "$plugin_file" "PLUGIN_DATE")"
    printf "  ${B:-\e[34m}Fichier     :${NC:-\e[0m} %s\n" "${plugin_file/$HOME/~}"
    local size
    size=$(du -sh "$plugin_file" 2>/dev/null | awk '{print $1}')
    printf "  ${B:-\e[34m}Taille      :${NC:-\e[0m} %s\n\n" "$size"

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  CRÉER LE PLUGIN D'EXEMPLE
# ═══════════════════════════════════════════════════════════════════════

_plg_create_example() {
    local example_file="$PLUGINS_DIR/exemple.plugin.sh"
    mkdir -p "$PLUGINS_DIR"

    [[ -f "$example_file" ]] && {
        ui_warning "Plugin exemple déjà présent."
        sleep 2; return 0
    }

    cat > "$example_file" << 'EXAMPLE'
#!/data/data/com.termux/files/usr/bin/bash
# ══════════════════════════════════════════════════════════════════════
# PLUGIN_NAME="Exemple"
# PLUGIN_VERSION="1.0"
# PLUGIN_DESCRIPTION="Plugin d'exemple avec toutes les fonctionnalités"
# PLUGIN_AUTHOR="Cyber Dashboard"
# PLUGIN_DATE="2025-01-01"
# ══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail

readonly PLG_NAME="Exemple"
readonly PLG_VERSION="1.0"

# Afficher la date et l'heure
_exemple_datetime() {
    printf "\n  ${C:-\e[36m}Date/Heure :${NC:-\e[0m} %s\n\n" "$(date '+%d/%m/%Y %H:%M:%S')"
}

# Calculatrice simple
_exemple_calc() {
    echo -ne "\n  ${C:-\e[36m}Expression (ex: 2+2, 10*5) : ${NC:-\e[0m}"
    read -r expr
    [[ -z "$expr" ]] && return
    local result
    result=$(echo "scale=2; $expr" | bc 2>/dev/null || echo "Erreur")
    printf "  ${G:-\e[32m}Résultat : %s${NC:-\e[0m}\n\n" "$result"
    read -rp "  Entrée..."
}

# Générateur de mot de passe
_exemple_password() {
    echo -ne "\n  ${C:-\e[36m}Longueur (défaut: 16) : ${NC:-\e[0m}"
    read -r len
    len="${len:-16}"
    [[ "$len" =~ ^[0-9]+$ ]] || len=16
    local password
    password=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$len")
    printf "\n  ${G:-\e[32m}Mot de passe : %s${NC:-\e[0m}\n\n" "$password"
    read -rp "  Entrée..."
}

# Point d'entrée obligatoire
plugin_menu() {
    while true; do
        clear
        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  🔌 Plugin %s v%s\n" "$PLG_NAME" "$PLG_VERSION"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Afficher date/heure\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Calculatrice\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Générateur de mot de passe\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Quitter\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  Choix : "; read -r choice

        case "$choice" in
            1) _exemple_datetime; read -rp "  Entrée..." ;;
            2) _exemple_calc     ;;
            3) _exemple_password ;;
            0|"") return 0       ;;
        esac
    done
}
EXAMPLE

    chmod +x "$example_file"
    ui_success "Plugin exemple créé : ${example_file/$HOME/~}"
    log_action "Plugin exemple créé" "plugins"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

plugins_menu() {
    log_action "Module plugins ouvert" "plugins"
    mkdir -p "$PLUGINS_DIR"

    while true; do
        clear
        _plg_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔌 ACTIONS PLUGINS${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Lancer un plugin\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Créer un plugin (template)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Installer depuis une URL\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Détails d'un plugin\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Supprimer un plugin\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Créer le plugin d'exemple\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _plg_run            ;;
            2) _plg_create         ;;
            3) _plg_install_url    ;;
            4) _plg_info           ;;
            5) _plg_delete         ;;
            6) _plg_create_example ;;
            0|"") log_action "Module plugins fermé" "plugins"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
