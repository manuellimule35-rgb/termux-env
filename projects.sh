#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# modules/projects.sh — Gestionnaire de projets locaux
# Dépend de : core/config.sh, core/logger.sh, core/ui.sh
#             core/utils.sh, core/security.sh, core/database.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

# Types de projets disponibles
readonly PROJ_TYPES=("web" "api" "cli" "lib" "mobile" "script" "data" "other")

# ═══════════════════════════════════════════════════════════════════════
#  LISTE DES PROJETS
# ═══════════════════════════════════════════════════════════════════════

_proj_list() {
    clear
    printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
    printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📁 PROJETS LOCAUX${NC:-\e[0m}\n"
    printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"

    local rows=""
    db_available 2>/dev/null && rows=$(db_project_list 2>/dev/null || echo "")

    if [[ -z "$rows" ]]; then
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Aucun projet enregistré.${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}Utilise [1] pour en ajouter un.${NC:-\e[0m}\n"
    else
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${D:-\e[2;37m}%-4s %-20s %-8s %s${NC:-\e[0m}\n" \
            "ID" "Nom" "Type" "Description"
        printf "${C:-\e[36m}║${NC:-\e[0m}  %s\n" "──────────────────────────────────────────────────────"
        while IFS='|' read -r id name type path desc; do
            # Indicateur existence dossier
            local icon
            [[ -d "$path" ]] \
                && icon="${G:-\e[32m}●${NC:-\e[0m}" \
                || icon="${R:-\e[31m}○${NC:-\e[0m}"
            printf "${C:-\e[36m}║${NC:-\e[0m}  %b ${B:-\e[34m}%-3s${NC:-\e[0m} %-20s %-8s %s\n" \
                "$icon" "$id" \
                "$(utils_truncate "$name" 19)" \
                "${type:-other}" \
                "$(utils_truncate "${desc:-}" 22)"
        done <<< "$rows"
    fi

    printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
}

# ═══════════════════════════════════════════════════════════════════════
#  AJOUTER UN PROJET
# ═══════════════════════════════════════════════════════════════════════

_proj_add() {
    clear
    ui_box_title "➕ AJOUTER UN PROJET"

    # Nom
    echo -ne "  ${C:-\e[36m}Nom du projet : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    # Chemin
    echo -ne "  ${C:-\e[36m}Chemin (défaut: $HOME/projets/$name) : ${NC:-\e[0m}"
    read -r path
    path="${path:-$HOME/projets/$name}"
    sec_safe_path "$path" 2>/dev/null || return 1

    # Type
    printf "\n  ${C:-\e[36m}Type :${NC:-\e[0m}\n"
    local i=1
    for t in "${PROJ_TYPES[@]}"; do
        printf "  ${B:-\e[34m}[%d]${NC:-\e[0m} %s\n" "$i" "$t"
        (( i++ ))
    done
    echo -ne "\n  ${C:-\e[36m}Choix (1-${#PROJ_TYPES[@]}) : ${NC:-\e[0m}"; read -r type_idx
    local type="other"
    if [[ "$type_idx" =~ ^[0-9]+$ ]] && \
       (( type_idx >= 1 && type_idx <= ${#PROJ_TYPES[@]} )); then
        type="${PROJ_TYPES[$((type_idx-1))]}"
    fi

    # Commande de lancement
    local lang
    lang=$(utils_detect_language "$path" 2>/dev/null || echo "unknown")
    local default_cmd
    default_cmd=$(utils_get_run_cmd "$lang" "$path")
    echo -ne "  ${C:-\e[36m}Commande lancement (défaut: $default_cmd) : ${NC:-\e[0m}"
    read -r run_cmd
    run_cmd="${run_cmd:-$default_cmd}"
    [[ -n "$run_cmd" ]] && \
        sec_safe_command "$run_cmd" 2>/dev/null || true

    # Description
    echo -ne "  ${C:-\e[36m}Description : ${NC:-\e[0m}"; read -r description

    # Créer le dossier si inexistant
    if [[ ! -d "$path" ]]; then
        echo -ne "  ${Y:-\e[33m}Dossier inexistant. Créer ? (o/n) : ${NC:-\e[0m}"
        read -r create_dir
        [[ "${create_dir,,}" == "o" ]] && utils_mkdir "$path"
    fi

    db_project_add "$name" "$type" "$path" "$run_cmd" "$description" \
        2>/dev/null || {
        ui_error "Échec ajout (nom peut-être déjà utilisé)."
        sleep 2; return 1
    }

    ui_success "Projet '$name' ajouté [$type]"
    log_action "Projet ajouté : $name ($type)" "projects"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  LANCER UN PROJET
# ═══════════════════════════════════════════════════════════════════════

_proj_run() {
    _proj_list
    echo -ne "  ${C:-\e[36m}Nom du projet à lancer : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_project_get "$name" 2>/dev/null || echo "")

    if [[ -z "$row" ]]; then
        ui_error "Projet '$name' introuvable en base."; sleep 2; return 1
    fi

    local path run_cmd type
    path=$(echo "$row" | cut -d'|' -f4)
    run_cmd=$(echo "$row" | cut -d'|' -f5)
    type=$(echo "$row" | cut -d'|' -f3)

    if [[ ! -d "$path" ]]; then
        ui_error "Dossier introuvable : $path"; sleep 2; return 1
    fi

    # Si pas de commande en BDD, détecter
    if [[ -z "$run_cmd" ]]; then
        local lang
        lang=$(utils_detect_language "$path")
        run_cmd=$(utils_get_run_cmd "$lang" "$path")
    fi

    if [[ -z "$run_cmd" ]]; then
        echo -ne "  ${C:-\e[36m}Commande de lancement : ${NC:-\e[0m}"; read -r run_cmd
        [[ -z "$run_cmd" ]] && return
        sec_safe_command "$run_cmd" 2>/dev/null || return 1
        # Sauvegarder pour la prochaine fois
        db_project_update_run_cmd "$name" "$run_cmd" 2>/dev/null || true
    fi

    printf "\n  ${B:-\e[34m}Projet   :${NC:-\e[0m} %s [%s]\n" "$name" "$type"
    printf "  ${B:-\e[34m}Commande :${NC:-\e[0m} %s\n" "$run_cmd"
    printf "  ${B:-\e[34m}Dossier  :${NC:-\e[0m} %s\n\n" "${path/$HOME/~}"

    log_action "Run projet : $name — $run_cmd" "projects"
    cd "$path" && eval "$run_cmd"
    local code=$?
    echo ""
    (( code == 0 )) \
        && printf "  ${G:-\e[32m}✅ Terminé (code 0).${NC:-\e[0m}\n" \
        || printf "  ${Y:-\e[33m}⚠️  Terminé avec code %d.${NC:-\e[0m}\n" "$code"
    read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MODIFIER UN PROJET
# ═══════════════════════════════════════════════════════════════════════

_proj_edit() {
    _proj_list
    echo -ne "  ${C:-\e[36m}Nom du projet à modifier : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    local row=""
    db_available 2>/dev/null && row=$(db_project_get "$name" 2>/dev/null || echo "")
    [[ -z "$row" ]] && { ui_error "Projet introuvable."; sleep 2; return 1; }

    local current_path current_cmd current_desc
    current_path=$(echo "$row" | cut -d'|' -f4)
    current_cmd=$(echo "$row" | cut -d'|' -f5)
    current_desc=$(echo "$row" | cut -d'|' -f6)

    clear
    ui_box_title "✏️  MODIFIER — $name"

    printf "  ${G:-\e[32m}[1]${NC:-\e[0m} Commande de lancement  [actuel: %s]\n" \
        "$(utils_truncate "$current_cmd" 35)"
    printf "  ${G:-\e[32m}[2]${NC:-\e[0m} Description            [actuel: %s]\n" \
        "$(utils_truncate "$current_desc" 35)"
    printf "  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n\n"
    echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r ch

    case "$ch" in
        1)
            echo -ne "  ${C:-\e[36m}Nouvelle commande (actuel: $current_cmd) : ${NC:-\e[0m}"
            read -r new_cmd
            [[ -z "$new_cmd" ]] && return
            sec_safe_command "$new_cmd" 2>/dev/null || return 1
            db_project_update_run_cmd "$name" "$new_cmd" 2>/dev/null || true
            ui_success "Commande mise à jour."; sleep 1
            ;;
        2)
            echo -ne "  ${C:-\e[36m}Nouvelle description : ${NC:-\e[0m}"; read -r new_desc
            db_exec "UPDATE projects SET description='${new_desc//\'/\'\'}',
                     updated_at=datetime('now') WHERE name='${name}';" \
                2>/dev/null || true
            ui_success "Description mise à jour."; sleep 1
            ;;
    esac
    log_action "Projet modifié : $name" "projects"
}

# ═══════════════════════════════════════════════════════════════════════
#  SUPPRIMER UN PROJET (BDD uniquement, pas le dossier)
# ═══════════════════════════════════════════════════════════════════════

_proj_delete() {
    _proj_list
    echo -ne "  ${C:-\e[36m}Projet à supprimer de la liste : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return
    sec_validate_name "$name" "Nom" 2>/dev/null || return 1

    printf "\n  ${Y:-\e[33m}Supprimer '%s' de la liste ? (o/n) : ${NC:-\e[0m}" "$name"
    read -r confirm
    [[ "${confirm,,}" != "o" ]] && return

    db_project_delete "$name" 2>/dev/null || true
    ui_success "Projet '$name' retiré de la liste."
    printf "  ${D:-\e[2;37m}(Le dossier physique n'a pas été supprimé)${NC:-\e[0m}\n"
    log_action "Projet retiré : $name" "projects"
    sleep 2
}

# ═══════════════════════════════════════════════════════════════════════
#  RECHERCHER
# ═══════════════════════════════════════════════════════════════════════

_proj_search() {
    echo -ne "\n  ${C:-\e[36m}Terme de recherche : ${NC:-\e[0m}"; read -r term
    [[ -z "$term" ]] && return
    sec_safe_string "$term" "Recherche" 2>/dev/null || return 1

    printf "\n  ${Y:-\e[33m}Résultats pour '%s' :${NC:-\e[0m}\n\n" "$term"

    local results=""
    db_available 2>/dev/null && \
        results=$(db_project_search "$term" 2>/dev/null || echo "")

    if [[ -n "$results" ]]; then
        while IFS='|' read -r id name type path desc; do
            local icon
            [[ -d "$path" ]] \
                && icon="${G:-\e[32m}●${NC:-\e[0m}" \
                || icon="${R:-\e[31m}○${NC:-\e[0m}"
            printf "  %b ${B:-\e[34m}[%s]${NC:-\e[0m} %-20s %-8s %s\n" \
                "$icon" "$id" "$name" "$type" \
                "$(utils_truncate "${desc:-}" 25)"
        done <<< "$results"
    else
        printf "  ${D:-\e[2;37m}Aucun résultat.${NC:-\e[0m}\n"
    fi
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  DÉTAILS D'UN PROJET
# ═══════════════════════════════════════════════════════════════════════

_proj_detail() {
    _proj_list
    echo -ne "  ${C:-\e[36m}Nom du projet : ${NC:-\e[0m}"; read -r name
    [[ -z "$name" ]] && return

    local row=""
    db_available 2>/dev/null && row=$(db_project_get "$name" 2>/dev/null || echo "")
    [[ -z "$row" ]] && { ui_error "Projet introuvable."; sleep 2; return 1; }

    local id p_name p_type p_path p_cmd p_desc p_created
    IFS='|' read -r id p_name p_type p_path p_cmd p_desc p_created <<< "$row"

    clear
    ui_box_title "🔍 DÉTAILS — $p_name"

    printf "  ${B:-\e[34m}ID          :${NC:-\e[0m} %s\n"   "$id"
    printf "  ${B:-\e[34m}Nom         :${NC:-\e[0m} %s\n"   "$p_name"
    printf "  ${B:-\e[34m}Type        :${NC:-\e[0m} %s\n"   "$p_type"
    printf "  ${B:-\e[34m}Chemin      :${NC:-\e[0m} %s\n"   "${p_path/$HOME/~}"
    printf "  ${B:-\e[34m}Commande    :${NC:-\e[0m} %s\n"   "${p_cmd:-(non définie)}"
    printf "  ${B:-\e[34m}Description :${NC:-\e[0m} %s\n"   "${p_desc:-(aucune)}"
    printf "  ${B:-\e[34m}Créé le     :${NC:-\e[0m} %s\n\n" "$p_created"

    # Infos filesystem
    if [[ -d "$p_path" ]]; then
        local lang size
        lang=$(utils_detect_language "$p_path")
        size=$(du -sh "$p_path" 2>/dev/null | awk '{print $1}' || echo "?")
        printf "  ${B:-\e[34m}Langage     :${NC:-\e[0m} %s\n" "$lang"
        printf "  ${B:-\e[34m}Taille      :${NC:-\e[0m} %s\n" "$size"
        printf "  ${G:-\e[32m}  ✅ Dossier présent${NC:-\e[0m}\n"
    else
        printf "  ${R:-\e[31m}  ❌ Dossier introuvable${NC:-\e[0m}\n"
    fi

    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  IMPORTER DES PROJETS EXISTANTS
# ═══════════════════════════════════════════════════════════════════════

_proj_import() {
    clear
    ui_box_title "📥 IMPORTER DES PROJETS EXISTANTS"
    printf "  ${D:-\e[2;37m}Scanne un dossier et importe tous les sous-dossiers comme projets.${NC:-\e[0m}\n\n"

    echo -ne "  ${C:-\e[36m}Dossier à scanner (défaut: $HOME) : ${NC:-\e[0m}"
    read -r scan_dir
    scan_dir="${scan_dir:-$HOME}"
    sec_safe_path "$scan_dir" 2>/dev/null || return 1
    [[ -d "$scan_dir" ]] || { ui_error "Dossier introuvable."; sleep 2; return 1; }

    printf "\n  ${Y:-\e[33m}Scan de %s...${NC:-\e[0m}\n\n" "${scan_dir/$HOME/~}"

    local imported=0 skipped=0

    while IFS= read -r -d '' dir; do
        local name
        name=$(basename "$dir")

        # Ignorer dossiers cachés et système
        [[ "$name" == .* ]] && continue
        [[ "$name" == "mon_env" ]] && continue

        # Vérifier si déjà en BDD
        local existing=""
        db_available 2>/dev/null && \
            existing=$(db_project_get "$name" 2>/dev/null || echo "")

        if [[ -n "$existing" ]]; then
            printf "  ${D:-\e[2;37m}⏭  %-25s (déjà importé)${NC:-\e[0m}\n" "$name"
            (( skipped++ ))
            continue
        fi

        local lang
        lang=$(utils_detect_language "$dir")
        local run_cmd
        run_cmd=$(utils_get_run_cmd "$lang" "$dir")

        db_project_add "$name" "other" "$dir" "$run_cmd" "Importé auto" \
            2>/dev/null && {
            printf "  ${G:-\e[32m}✅ %-25s [%s]${NC:-\e[0m}\n" "$name" "$lang"
            (( imported++ ))
        } || {
            printf "  ${Y:-\e[33m}⚠️  %-25s (échec)${NC:-\e[0m}\n" "$name"
        }

    done < <(find "$scan_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    printf "\n  ${G:-\e[32m}%d importés${NC:-\e[0m}  ${D:-\e[2;37m}%d ignorés${NC:-\e[0m}\n" \
        "$imported" "$skipped"
    log_action "Import projets : $imported OK / $skipped ignorés" "projects"
    echo ""; read -rp "  Entrée..."
}

# ═══════════════════════════════════════════════════════════════════════
#  MENU PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════

projects_menu() {
    log_action "Module projets ouvert" "projects"

    while true; do
        clear
        _proj_list

        printf "${C:-\e[36m}╔══════════════════════════════════════════════════════════════╗${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${Y:-\e[33m}📁 ACTIONS PROJETS${NC:-\e[0m}\n"
        printf "${C:-\e[36m}╠══════════════════════════════════════════════════════════════╣${NC:-\e[0m}\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[1]${NC:-\e[0m} Ajouter un projet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[2]${NC:-\e[0m} Lancer un projet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[3]${NC:-\e[0m} Voir les détails\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[4]${NC:-\e[0m} Modifier un projet\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[5]${NC:-\e[0m} Supprimer de la liste\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[6]${NC:-\e[0m} Rechercher\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[7]${NC:-\e[0m} Importer projets existants\n"
        printf "${C:-\e[36m}║${NC:-\e[0m}  ${G:-\e[32m}[0]${NC:-\e[0m} Retour\n"
        printf "${C:-\e[36m}╚══════════════════════════════════════════════════════════════╝${NC:-\e[0m}\n\n"
        echo -ne "  ${C:-\e[36m}Choix : ${NC:-\e[0m}"; read -r choice

        case "$choice" in
            1) _proj_add    ;;
            2) _proj_run    ;;
            3) _proj_detail ;;
            4) _proj_edit   ;;
            5) _proj_delete ;;
            6) _proj_search ;;
            7) _proj_import ;;
            0|"") log_action "Module projets fermé" "projects"; return 0 ;;
            *) ui_warning "Choix invalide"; sleep 1 ;;
        esac
    done
}
