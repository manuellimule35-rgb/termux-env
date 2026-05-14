#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/scripts.sh — Gestionnaire de scripts personnels
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPTS_STORE_DIR="${CFG_INSTALL_DIR:-$HOME/mon_env}/scripts"
readonly SCRIPT_CATEGORIES=("general" "réseau" "backup" "monitoring" "pentest" "utilitaire")

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES SCRIPTS
# ═══════════════════════════════════════════════════════════════════════

_scr_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔧 SCRIPTS PERSONNELS${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local rows=""
    db_available 2>/dev/null && rows=$(db_script_list 2>/dev/null || echo "")

    if [[ -z "$rows" ]]; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun script enregistré.${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Utilise [1] pour en ajouter un.${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%-4s %-20s %-12s %s${NC:-\e[0m}\n" \
            "ID" "Nom" "Catégorie" "Description"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %s\n" \
            "──────────────────────────────────────────────────────────"
        while IFS='|' read -r id name cat desc path; do
            local icon
            [[ -f "$path" ]] \
                && icon="${G:-\e[32m}●${NC:-\e[0m}" \
                || icon="${R:-\e[31m}○${NC:-\e[0m}"
            printf "${C:-\e[36m}║${NC:-\e[0m}  %b ${B:-\e[34m}%-3s${NC:-\e[0m} %-20s %-12s %s\n" \
                "$icon" "$id" \
                "$(utils_truncate "$name" 19)" \
                "${cat:-general}" \
                "$(utils_truncate "${desc:-}" 22)"
        done <<< "$rows"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  AJOUTER UN SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_add() {
    clear
    ui_box_title "➕ AJOUTER UN SCRIPT"

    echo -ne "  ${C:-\e[36m}Nom du script : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    echo -ne "  ${C:-\e[36m}Description : ${NC:-\e[0m}"; read -r description

    # Catégorie
    printf "\n  ${C:-\e[36m}Catégorie :${NC:-\e[0m}\n"
    local i=1
    for cat in "${SCRIPT_CATEGORIES[@]}"; do
        printf "  ${B:-\e[34m}[%d]${NC:-\e[0m} %s\n" "$i" "$cat"
        (( i++ ))
    done
    echo -ne "\n  ${C:-\e[36m}Choix (défaut: 1) : ${NC:-\e[0m}"; read -r cat_idx
    cat_idx="${cat_idx:-1}"
    local category="general"
    if [[ "$cat_idx" =~ ^[0-9]+$ ]] && \
       (( cat_idx >= 1 && cat_idx <= ${#SCRIPT_CATEGORIES[@]} )); then
        category="${SCRIPT_CATEGORIES[$((cat_idx-1))]}"
    fi

    # Chemin ou créer nouveau
    printf "\n  ${G:-\e[32m}[1]${NC:-\e[0m} Pointer vers un script existant\n"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Créer un nouveau script\n\n"
    echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r src_choice

    local script_path=""

    case "$src_choice" in
        1)
            echo -ne "  ${C:-\e[36m}Chemin du script : ${NC:-\e[0m}"; read -r script_path
            script_path="${script_path/#\~/$HOME}"
            sec_safe_path "$script_path" 2>/dev/null || return 1
            [[ -f "$script_path" ]] || {
                ui_error "Fichier introuvable : $script_path"
                sleep 2; return 1
            }
            ;;
        2)
            mkdir -p "$SCRIPTS_STORE_DIR"
            script_path="$SCRIPTS_STORE_DIR/${name}.sh"
            _scr_create_template "$script_path" "$name" "$description"
            ;;
        *)
            return 0
            ;;
    esac

    # Commande de lancement
    local default_run="bash ${script_path}"
    echo -ne "  ${C:-\e[36m}Commande (défaut: $default_run) : ${NC:-\e[0m}"
    read -r run_cmd
    run_cmd="${run_cmd:-$default_run}"
    sec_safe_command "$run_cmd" 2>/dev/null || return 1

    # Rendre exécutable
    chmod +x "$script_path" 2>/dev/null || true

    db_script_add "$name" "$description" "$script_path" \
        "$run_cmd" "$category" 2>/dev/null || {
        ui_error "Échec ajout (nom peut-être déjà utilisé)."
        sleep 2; return 1
    }

    ui_success "Script '$name' ajouté [$category]"
    log_action "Script ajouté : $name ($category)" "scripts"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  CRÉER UN TEMPLATE DE SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_create_template() {
    local path="$1"
    local name="$2"
    local desc="$3"

    cat > "$path" << TEMPLATE
#!/data/data/com.termux/files/usr/bin/bash
# ══════════════════════════════════════
# Script : ${name}
# Description : ${desc}
# Créé le : $(date '+%d/%m/%Y')
# Cyber Dashboard Termux v1.0
# ══════════════════════════════════════

set -Eeuo pipefail

# ─── Variables ────────────────────────
SCRIPT_NAME="${name}"

# ─── Fonctions ────────────────────────
main() {
    echo "Script : \$SCRIPT_NAME"
    echo "Modifie ce fichier pour ajouter ta logique."
}

main "\$@"
TEMPLATE

    chmod +x "$path"

    # Ouvrir dans nano pour édition immédiate
    printf "\n  ${Y:-\e[33m}Template créé. Ouvrir dans nano pour éditer ? (o/n) : ${NC:-\e[0m}"
    read -r edit_now
    [[ "${edit_now,,}" == "o" ]] && utils_cmd_exists nano && nano "$path"
}

# ═══════════════════════════════════════════════════════════════════════
#  LANCER UN SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_run() {
    _scr_list
    echo -ne "  ${C:-\e[36m}Nom du script à lancer : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_script_get "$name" 2>/dev/null || echo "")

    if [[ -z "$row" ]]; then
        ui_error "Script '$name' introuvable."; sleep 2; return 1
    fi

    local _id _name desc path run_cmd _cat
    IFS='|' read -r _id _name desc path run_cmd _cat <<< "$row"

    [[ -f "$path" ]] || {
        ui_error "Fichier manquant : $path"; sleep 2; return 1
    }

    printf "\n  ${B:-\e[34m}Script   :${NC:-\e[0m} %s\n" "$_name"
    printf "  ${B:-\e[34m}Commande :${NC:-\e[0m} %s\n" "$run_cmd"
    printf "  ${B:-\e[34m}Fichier  :${NC:-\e[0m} %s\n\n" "${path/$HOME/~}"

    # Arguments optionnels
    echo -ne "  ${C:-\e[36m}Arguments (optionnel) : ${NC:-\e[0m}"; read -r args
    [[ -n "$args" ]] && sec_safe_string "$args" "Arguments" 2>/dev/null || true

    log_action "Run script : $name" "scripts"

    local full_cmd="$run_cmd"
    [[ -n "$args" ]] && full_cmd+=" $args"

    printf "  ${Y:-\e[33m}Exécution...${NC:-\e[0m}\n\n"
    eval "$full_cmd"
    local code=$?
    echo ""
    (( code == 0 )) \
        && printf "  ${G:-\e[32m}✅ Terminé (code 0).${NC:-\e[0m}\n" \
        || printf "  ${Y:-\e[33m}⚠️  Terminé avec code %d.${NC:-\e[0m}\n" "$code"
    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉDITER UN SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_edit() {
    _scr_list
    echo -ne "  ${C:-\e[36m}Nom du script à éditer : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_script_get "$name" 2>/dev/null || echo "")
    [[ -z "$row" ]] && { ui_error "Script introuvable."; sleep 2; return 1; }

    local path
    path=$(echo "$row" | cut -d'|' -f4)
    [[ -f "$path" ]] || { ui_error "Fichier manquant : $path"; sleep 2; return 1; }

    log_action "Édition script : $name" "scripts"

    # Choisir l'éditeur
    if utils_cmd_exists nano; then
        nano "$path"
    elif utils_cmd_exists vim; then
        vim "$path"
    else
        ui_warning "Aucun éditeur disponible (nano/vim)."; sleep 2
    fi
}

# ═══════════════════════════════════════════════════════════════════════
#  AFFICHER UN SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_view() {
    _scr_list
    echo -ne "  ${C:-\e[36m}Nom du script à afficher : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return

    local row=""
    db_available 2>/dev/null && row=$(db_script_get "$name" 2>/dev/null || echo "")
    [[ -z "$row" ]] && { ui_error "Script introuvable."; sleep 2; return 1; }

    local path
    path=$(echo "$row" | cut -d'|' -f4)
    [[ -f "$path" ]] || { ui_error "Fichier manquant."; sleep 2; return 1; }

    clear
    ui_box_title "👁️  CONTENU — $name"

    # Affichage avec numéros de lignes
    local line_num=1
    while IFS= read -r line; do
        printf "  ${D:-\e[2;37m}%3d${NC:-\e[0m}  %s\n" "$line_num" "$line"
        (( line_num++ ))
    done < "$path"

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN SCRIPT
# ═══════════════════════════════════════════════════════════════════════

_scr_delete() {
    _scr_list
    echo -ne "  ${C:-\e[36m}Nom du script à supprimer : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_script_get "$name" 2>/dev/null || echo "")
    [[ -z "$row" ]] && { ui_error "Script introuvable."; sleep 2; return 1; }

    local path
    path=$(echo "$row" | cut -d'|' -f4)

    printf "  ${Y:-\e[33m}Supprimer '%s' de la liste ? (o/n) : ${NC:-\e[0m}" "$name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    db_script_delete "$name" 2>/dev/null || true

    # Supprimer le fichier physique si dans SCRIPTS_STORE_DIR
    if [[ "$path" == "$SCRIPTS_STORE_DIR"* && -f "$path" ]]; then
        printf "  ${Y:-\e[33m}Supprimer aussi le fichier %s ? (o/n) : ${NC:-\e[0m}" \
            "${path/$HOME/~}"
        read -r del_file
        [[ "${del_file,,}" == "o" ]] && \
            sec_safe_remove "$path" "true" 2>/dev/null || true
    fi

    ui_success "Script '$name' supprimé."
    log_action "Script supprimé : $name" "scripts"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  RECHERCHE
# ═══════════════════════════════════════════════════════════════════════

_scr_search() {
    echo -ne "\n  ${C:-\e[36m}Terme de recherche : ${NC:-\e[0m}"; read -r term
    [[ -z "$term" ]] && return
    sec_safe_string "$term" "Recherche" 2>/dev/null || return 1

    printf "\n  ${Y:-\e[33m}Résultats pour '%s' :${NC:-\e[0m}\n\n" "$term"

    if db_available 2>/dev/null; then
        local results
        results=$(db_query \
            "SELECT id, name, category, description FROM scripts
             WHERE name LIKE '%${term}%' OR description LIKE '%${term}%'
             ORDER BY name;" 2>/dev/null || echo "")
        if [[ -n "$results" ]]; then
            while IFS='|' read -r id name cat desc; do
                printf "  ${B:-\e[34m}[%s]${NC:-\e[0m} %-20s %-12s %s\n" \
                    "$id" "$name" "$cat" \
                    "$(utils_truncate "${desc:-}" 25)"
            done <<< "$results"
        else
            printf "  ${D:-\e[2;37m}Aucun résultat.${NC:-\e[0m}\n"
        fi
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

scripts_menu() {
    log_action "Module scripts ouvert" "scripts"
    mkdir -p "$SCRIPTS_STORE_DIR"

    while true; do
        clear
        _scr_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}🔧 ACTIONS SCRIPTS${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Ajouter / Créer un script\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Lancer un script\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Éditer un script\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Afficher le contenu\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Supprimer un script\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Rechercher\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _scr_add    ;;
            2) _scr_run    ;;
            3) _scr_edit   ;;
            4) _scr_view   ;;
            5) _scr_delete ;;
            6) _scr_search ;;
            0|"") log_action "Module scripts fermé" "scripts"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
