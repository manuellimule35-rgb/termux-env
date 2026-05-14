#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/notes.sh — Gestionnaire de notes : ajout, lecture, recherche
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# Catégories disponibles
readonly NOTE_CATEGORIES=("general" "todo" "idee" "code" "securite" "réseau" "perso")

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES NOTES
# ═══════════════════════════════════════════════════════════════════════

_note_list() {
    local category="${1:-}"
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📝 NOTES${NC:-\e[0m}"
    [[ -n "$category" ]] && printf " — Catégorie : ${B:-\e[34m}%s${NC:-\e[0m}" "$category"
    printf "\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local rows=""
    if db_available 2>/dev/null; then
        rows=$(db_note_list "$category" 2>/dev/null || echo "")
    fi

    if [[ -z "$rows" ]]; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucune note trouvée.${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Utilise [1] pour créer une note rapide.${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%-4s %-25s %-10s %s${NC:-\e[0m}\n" \
            "ID" "Titre" "Catégorie" "Date"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %s\n" \
            "──────────────────────────────────────────────────────────"
        while IFS='|' read -r id title cat _tags created; do
            # Couleur par catégorie
            local color
            case "$cat" in
                todo)     color="${Y:-\e[33m}" ;;
                securite) color="${R:-\e[31m}" ;;
                code)     color="${G:-\e[32m}" ;;
                idee)     color="${M:-\e[35m}" ;;
                *)        color="${C:-\e[36m}" ;;
            esac
            printf "${C:-\e[36m}║${NC:-\e[0m}  ${B:-\e[34m}%-4s${NC:-\e[0m} %b%-25s${NC:-\e[0m} %-10s %s\n" \
                "$id" "$color" \
                "$(utils_truncate "$title" 24)" \
                "${cat:-general}" \
                "$(echo "$created" | cut -c1-10)"
        done <<< "$rows"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  NOTE RAPIDE (une ligne, saisie directe)
# ═══════════════════════════════════════════════════════════════════════

_note_quick() {
    echo -ne "\n  ${C:-\e[36m}Note rapide (titre | contenu) : ${NC:-\e[0m}"
    read -r quick_input

    [[ -z "$quick_input" ]] && return

    local title content
    if [[ "$quick_input" == *"|"* ]]; then
        title=$(echo "$quick_input" | cut -d'|' -f1 | xargs)
        content=$(echo "$quick_input" | cut -d'|' -f2- | xargs)
    else
        title="Note rapide $(date '+%H:%M')"
        content="$quick_input"
    fi

    sec_safe_string "$title" "Titre" 2>/dev/null || return 1

    db_note_add "$title" "$content" "general" "" 2>/dev/null || {
        ui_error "Échec sauvegarde note."; sleep 2; return 1
    }

    ui_success "Note sauvegardée : $title"
    utils_notify "Note sauvegardée" "$title" 2>/dev/null || true
    log_action "Note rapide ajoutée : $title" "notes"
    sleep 1
}

# ═══════════════════════════════════════════════════════════════════════
#  CRÉER UNE NOTE COMPLÈTE
# ═══════════════════════════════════════════════════════════════════════

_note_create() {
    clear
    ui_box_title "📝 CRÉER UNE NOTE"

    # Titre
    echo -ne "  ${C:-\e[36m}Titre : ${NC:-\e[0m}"; read -r title
    [[ -z "$title" ]] && return
    sec_safe_string "$title" "Titre" 2>/dev/null || return 1

    # Catégorie
    printf "\n  ${C:-\e[36m}Catégorie :${NC:-\e[0m}\n"
    local i=1
    for cat in "${NOTE_CATEGORIES[@]}"; do
        printf "  ${B:-\e[34m}[%d]${NC:-\e[0m} %s\n" "$i" "$cat"
        (( i++ ))
    done
    echo -ne "\n  ${C:-\e[36m}Choix (défaut: 1=general) : ${NC:-\e[0m}"; read -r cat_idx
    cat_idx="${cat_idx:-1}"
    local category="general"
    if [[ "$cat_idx" =~ ^[0-9]+$ ]] && \
       (( cat_idx >= 1 && cat_idx <= ${#NOTE_CATEGORIES[@]} )); then
        category="${NOTE_CATEGORIES[$((cat_idx-1))]}"
    fi

    # Tags
    echo -ne "  ${C:-\e[36m}Tags (séparés par virgules, optionnel) : ${NC:-\e[0m}"
    read -r tags

    # Contenu
    printf "\n  ${C:-\e[36m}Contenu (termine avec une ligne vide) :${NC:-\e[0m}\n"
    printf "  ${D:-\e[2;37m}(ou 'EDITOR' pour ouvrir nano)${NC:-\e[0m}\n\n"

    local content=""
    read -r first_line
    if [[ "${first_line,,}" == "editor" ]]; then
        # Ouvrir dans nano
        local tmp_file
        tmp_file=$(mktemp /tmp/cyd_note_XXXXX.txt)
        nano "$tmp_file" 2>/dev/null
        [[ -f "$tmp_file" ]] && content=$(cat "$tmp_file") && rm -f "$tmp_file"
    else
        content="$first_line"$'\n'
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            content+="$line"$'\n'
        done
    fi

    [[ -z "$content" ]] && { ui_warning "Contenu vide, note non sauvegardée."; sleep 1; return; }

    db_note_add "$title" "$content" "$category" "$tags" 2>/dev/null || {
        ui_error "Échec sauvegarde."; sleep 2; return 1
    }

    ui_success "Note créée : $title [$category]"
    log_action "Note créée : $title" "notes"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  LIRE UNE NOTE
# ═══════════════════════════════════════════════════════════════════════

_note_read() {
    _note_list
    echo -ne "  ${C:-\e[36m}ID de la note à lire : ${NC:-\e[0m}"; read -r note_id
    [[ -z "$note_id" || ! "$note_id" =~ ^[0-9]+$ ]] && return

    local row=""
    db_available 2>/dev/null && row=$(db_note_get "$note_id" 2>/dev/null || echo "")

    if [[ -z "$row" ]]; then
        ui_error "Note #$note_id introuvable."; sleep 2; return 1
    fi

    local _id title content category tags created updated
    IFS='|' read -r _id title content category tags created updated <<< "$row"

    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}%s${NC:-\e[0m}\n" "$title"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Catégorie : %-12s Tags : %-20s${NC:-\e[0m}\n" \
        "$category" "${tags:-(aucun)}"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Créée : %-18s Modifiée : %s${NC:-\e[0m}\n" \
        "$(echo "$created" | cut -c1-16)" \
        "$(echo "$updated" | cut -c1-16)"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
    printf "\n"

    # Afficher le contenu avec indentation
    while IFS= read -r line; do
        printf "  %s\n" "$line"
    done <<< "$content"

    printf "\n${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"

    printf "  ${G:-\e[32m}[e]${NC:-\e[0m} Éditer  ${R:-\e[31m}[d]${NC:-\e[0m} Supprimer  "
    printf "${B:-\e[34m}[c]${NC:-\e[0m} Copier  ${D:-\e[2;37m}[Entrée]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Action : ${NC:-\e[0m}"; read -r action

    case "${action,,}" in
        e) _note_edit_content "$note_id" "$content" ;;
        d) _note_delete_by_id "$note_id" "$title"   ;;
        c)
            utils_clipboard_copy "$title"$'\n'"$content" 2>/dev/null && \
                ui_success "Note copiée dans le presse-papier." || \
                ui_warning "Presse-papier non disponible."
            sleep 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════
#  ÉDITER LE CONTENU D'UNE NOTE
# ═══════════════════════════════════════════════════════════════════════

_note_edit_content() {
    local note_id="$1"
    local current_content="$2"

    # Écrire dans un fichier temporaire
    local tmp_file
    tmp_file=$(mktemp /tmp/cyd_note_edit_XXXXX.txt)
    echo "$current_content" > "$tmp_file"

    if utils_cmd_exists nano; then
        nano "$tmp_file"
    elif utils_cmd_exists vim; then
        vim "$tmp_file"
    else
        printf "\n  ${Y:-\e[33m}Éditeur non disponible. Saisis le nouveau contenu :${NC:-\e[0m}\n"
        : > "$tmp_file"
        while IFS= read -r line; do
            [[ -z "$line" ]] && break
            echo "$line" >> "$tmp_file"
        done
    fi

    local new_content
    new_content=$(cat "$tmp_file")
    rm -f "$tmp_file"

    if [[ -n "$new_content" ]]; then
        db_note_update "$note_id" "$new_content" 2>/dev/null || true
        ui_success "Note #$note_id mise à jour."
        log_action "Note éditée : id=$note_id" "notes"
    else
        ui_warning "Contenu vide — note non modifiée."
    fi
    sleep 1
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UNE NOTE
# ═══════════════════════════════════════════════════════════════════════

_note_delete_by_id() {
    local note_id="$1"
    local title="${2:-#$note_id}"

    printf "  ${R:-\e[31m}Supprimer la note '%s' ? (o/n) : ${NC:-\e[0m}" "$title"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    db_note_delete "$note_id" 2>/dev/null || true
    ui_success "Note supprimée."
    log_action "Note supprimée : id=$note_id" "notes"
    sleep 1
}

_note_delete() {
    _note_list
    echo -ne "  ${C:-\e[36m}ID de la note à supprimer : ${NC:-\e[0m}"; read -r note_id
    [[ -z "$note_id" || ! "$note_id" =~ ^[0-9]+$ ]] && return
    _note_delete_by_id "$note_id"
}

# ═══════════════════════════════════════════════════════════════════════
#  RECHERCHE
# ═══════════════════════════════════════════════════════════════════════

_note_search() {
    echo -ne "\n  ${C:-\e[36m}Terme de recherche : ${NC:-\e[0m}"; read -r term
    [[ -z "$term" ]] && return
    sec_safe_string "$term" "Recherche" 2>/dev/null || return 1

    printf "\n  ${Y:-\e[33m}Résultats pour '%s' :${NC:-\e[0m}\n\n" "$term"

    local results=""
    db_available 2>/dev/null && \
        results=$(db_note_search "$term" 2>/dev/null || echo "")

    if [[ -n "$results" ]]; then
        while IFS='|' read -r id title cat created; do
            printf "  ${B:-\e[34m}[%s]${NC:-\e[0m} %-28s %-10s %s\n" \
                "$id" \
                "$(utils_truncate "$title" 27)" \
                "$cat" \
                "$(echo "$created" | cut -c1-10)"
        done <<< "$results"
    else
        printf "  ${D:-\e[2;37m}Aucun résultat.${NC:-\e[0m}\n"
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  EXPORTER LES NOTES
# ═══════════════════════════════════════════════════════════════════════

_note_export() {
    local export_file
    export_file="${CFG_LOGS_DIR:-$HOME/mon_env/logs}/notes_export_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "═══════════════════════════════════════════"
        echo " EXPORT NOTES — $(date '+%d/%m/%Y %H:%M')"
        echo "═══════════════════════════════════════════"
        echo ""

        local rows=""
        db_available 2>/dev/null && rows=$(db_note_list "" 2>/dev/null || echo "")

        if [[ -n "$rows" ]]; then
            while IFS='|' read -r id title cat _tags created; do
                local full_row=""
                db_available 2>/dev/null && \
                    full_row=$(db_note_get "$id" 2>/dev/null || echo "")
                local content
                content=$(echo "$full_row" | cut -d'|' -f3)

                echo "───────────────────────────────────────────"
                echo "Titre      : $title"
                echo "Catégorie  : $cat"
                echo "Date       : $(echo "$created" | cut -c1-16)"
                echo ""
                echo "$content"
                echo ""
            done <<< "$rows"
        else
            echo "Aucune note."
        fi
    } > "$export_file"

    printf "\n  ${G:-\e[32m}✅ Export : %s${NC:-\e[0m}\n" "${export_file/$HOME/~}"
    log_action "Notes exportées : $export_file" "notes"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

notes_menu() {
    log_action "Module notes ouvert" "notes"

    while true; do
        clear
        _note_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📝 ACTIONS NOTES${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Note rapide (une ligne)\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Créer une note complète\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Lire une note\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Supprimer une note\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Rechercher\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Filtrer par catégorie\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[7]${NC:-\e[0m} Exporter toutes les notes\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _note_quick  ;;
            2) _note_create ;;
            3) _note_read   ;;
            4) _note_delete ;;
            5) _note_search ;;
            6)
                printf "\n  ${C:-\e[36m}Catégories : %s${NC:-\e[0m}\n" \
                    "${NOTE_CATEGORIES[*]}"
                echo -ne "  ${C:-\e[36m}Catégorie : ${NC:-\e[0m}"; read -r cat
                _note_list "$cat"
                read -rp "  Entrée..."
                ;;
            7) _note_export ;;
            0|"") log_action "Module notes fermé" "notes"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
