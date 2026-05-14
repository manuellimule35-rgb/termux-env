#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════════════
# core/database.sh — Interface SQLite pour tous les modules
# Dépend de : core/config.sh, core/logger.sh
# ═══════════════════════════════════════════════════════════════════════

set -Eeuo pipefail
IFS=$'\n\t'

readonly DB_FILE="${CFG_DATABASE_FILE:-$HOME/mon_env/database/env.db}"

# ═══════════════════════════════════════════════════════════════════════
#  PRIMITIVES DE BASE
# ═══════════════════════════════════════════════════════════════════════

# Vérifier que sqlite3 est disponible
db_available() {
    command -v sqlite3 &>/dev/null && [[ -f "$DB_FILE" ]]
}

# Exécuter une requête SQL (retourne les résultats)
db_query() {
    local sql="$1"
    local sep="${2:-|}"

    if ! db_available; then
        log_warn "SQLite non disponible" "database"
        return 1
    fi

    sqlite3 -separator "$sep" "$DB_FILE" "$sql" 2>/dev/null || {
        log_error "Erreur SQL : $sql" "database"
        return 1
    }
}

# Exécuter sans retour (INSERT / UPDATE / DELETE)
db_exec() {
    local sql="$1"

    if ! db_available; then
        log_warn "SQLite non disponible" "database"
        return 1
    fi

    sqlite3 "$DB_FILE" "$sql" 2>/dev/null || {
        log_error "Erreur SQL exec : $sql" "database"
        return 1
    }
}

# Compter les lignes d'une table
db_count() {
    local table="$1"
    local where="${2:-1=1}"
    db_query "SELECT COUNT(*) FROM ${table} WHERE ${where};" 2>/dev/null || echo 0
}

# ═══════════════════════════════════════════════════════════════════════
#  SETTINGS (paramètres globaux)
# ═══════════════════════════════════════════════════════════════════════

db_setting_get() {
    local key="$1"
    local default="${2:-}"
    local val
    val=$(db_query "SELECT value FROM settings WHERE key='${key}';" 2>/dev/null || echo "")
    echo "${val:-$default}"
}

db_setting_set() {
    local key="$1"
    local value="$2"
    db_exec "INSERT OR REPLACE INTO settings (key, value, updated_at)
             VALUES ('${key}', '${value}', datetime('now'));" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════
#  PROJETS LOCAUX
# ═══════════════════════════════════════════════════════════════════════

db_project_add() {
    local name="$1"
    local type="${2:-other}"
    local path="$3"
    local run_cmd="${4:-}"
    local description="${5:-}"

    db_exec "INSERT OR IGNORE INTO projects (name, type, path, run_cmd, description)
             VALUES ('${name}', '${type}', '${path}', '${run_cmd}', '${description}');"
    log_info "Projet ajouté : $name" "database"
}

db_project_delete() {
    local name="$1"
    db_exec "DELETE FROM projects WHERE name='${name}';"
    log_info "Projet supprimé : $name" "database"
}

db_project_list() {
    db_query "SELECT id, name, type, path, description
              FROM projects ORDER BY name;" "|"
}

db_project_get() {
    local name="$1"
    db_query "SELECT id, name, type, path, run_cmd, description, created_at
              FROM projects WHERE name='${name}';" "|"
}

db_project_search() {
    local term="$1"
    db_query "SELECT id, name, type, path, description
              FROM projects
              WHERE name LIKE '%${term}%' OR description LIKE '%${term}%'
              ORDER BY name;" "|"
}

db_project_update_run_cmd() {
    local name="$1"
    local run_cmd="$2"
    db_exec "UPDATE projects SET run_cmd='${run_cmd}', updated_at=datetime('now')
             WHERE name='${name}';"
}

# ═══════════════════════════════════════════════════════════════════════
#  PROJETS GITHUB
# ═══════════════════════════════════════════════════════════════════════

db_github_add() {
    local name="$1"
    local url="$2"
    local local_path="$3"
    local branch="${4:-main}"
    local language="${5:-unknown}"
    local description="${6:-}"

    db_exec "INSERT OR IGNORE INTO github_projects
             (name, url, local_path, branch, language, description)
             VALUES ('${name}', '${url}', '${local_path}',
                     '${branch}', '${language}', '${description}');"
    log_info "GitHub projet ajouté : $name" "database"
}

db_github_delete() {
    local name="$1"
    db_exec "DELETE FROM github_projects WHERE name='${name}';"
    log_info "GitHub projet supprimé : $name" "database"
}

db_github_list() {
    db_query "SELECT id, name, url, branch, language, last_pull
              FROM github_projects ORDER BY name;" "|"
}

db_github_get() {
    local name="$1"
    db_query "SELECT id, name, url, local_path, branch, language, description, last_pull
              FROM github_projects WHERE name='${name}';" "|"
}

db_github_update_pull() {
    local name="$1"
    db_exec "UPDATE github_projects SET last_pull=datetime('now')
             WHERE name='${name}';"
}

db_github_search() {
    local term="$1"
    db_query "SELECT id, name, url, language, description
              FROM github_projects
              WHERE name LIKE '%${term}%' OR description LIKE '%${term}%'
              ORDER BY name;" "|"
}

# ═══════════════════════════════════════════════════════════════════════
#  NOTES
# ═══════════════════════════════════════════════════════════════════════

db_note_add() {
    local title="$1"
    local content="$2"
    local category="${3:-general}"
    local tags="${4:-}"

    # Échapper les apostrophes dans le contenu
    local safe_content="${content//\'/\'\'}"
    local safe_title="${title//\'/\'\'}"

    db_exec "INSERT INTO notes (title, content, category, tags)
             VALUES ('${safe_title}', '${safe_content}',
                     '${category}', '${tags}');"
    log_info "Note ajoutée : $title" "database"
}

db_note_delete() {
    local id="$1"
    db_exec "DELETE FROM notes WHERE id=${id};"
    log_info "Note supprimée : id=$id" "database"
}

db_note_list() {
    local category="${1:-}"
    if [[ -n "$category" ]]; then
        db_query "SELECT id, title, category, tags, created_at
                  FROM notes WHERE category='${category}'
                  ORDER BY created_at DESC;" "|"
    else
        db_query "SELECT id, title, category, tags, created_at
                  FROM notes ORDER BY created_at DESC;" "|"
    fi
}

db_note_get() {
    local id="$1"
    db_query "SELECT id, title, content, category, tags, created_at, updated_at
              FROM notes WHERE id=${id};" "|"
}

db_note_search() {
    local term="$1"
    db_query "SELECT id, title, category, created_at
              FROM notes
              WHERE title LIKE '%${term}%' OR content LIKE '%${term}%'
              ORDER BY created_at DESC;" "|"
}

db_note_update() {
    local id="$1"
    local content="$2"
    local safe_content="${content//\'/\'\'}"
    db_exec "UPDATE notes SET content='${safe_content}', updated_at=datetime('now')
             WHERE id=${id};"
}

# ═══════════════════════════════════════════════════════════════════════
#  SSH HOSTS
# ═══════════════════════════════════════════════════════════════════════

db_ssh_add() {
    local alias_name="$1"
    local username="$2"
    local host="$3"
    local port="${4:-22}"
    local key_path="${5:-}"
    local description="${6:-}"

    db_exec "INSERT OR IGNORE INTO ssh_hosts
             (alias, username, host, port, key_path, description)
             VALUES ('${alias_name}', '${username}', '${host}',
                     ${port}, '${key_path}', '${description}');"
    log_info "SSH host ajouté : $alias_name → $username@$host:$port" "database"
}

db_ssh_delete() {
    local alias_name="$1"
    db_exec "DELETE FROM ssh_hosts WHERE alias='${alias_name}';"
    log_info "SSH host supprimé : $alias_name" "database"
}

db_ssh_list() {
    db_query "SELECT id, alias, username, host, port, description
              FROM ssh_hosts ORDER BY alias;" "|"
}

db_ssh_get() {
    local alias_name="$1"
    db_query "SELECT id, alias, username, host, port, key_path, description
              FROM ssh_hosts WHERE alias='${alias_name}';" "|"
}

# ═══════════════════════════════════════════════════════════════════════
#  SCRIPTS
# ═══════════════════════════════════════════════════════════════════════

db_script_add() {
    local name="$1"
    local description="$2"
    local path="$3"
    local run_cmd="${4:-bash $3}"
    local category="${5:-general}"

    db_exec "INSERT OR IGNORE INTO scripts (name, description, path, run_cmd, category)
             VALUES ('${name}', '${description}', '${path}',
                     '${run_cmd}', '${category}');"
    log_info "Script ajouté : $name" "database"
}

db_script_delete() {
    local name="$1"
    db_exec "DELETE FROM scripts WHERE name='${name}';"
    log_info "Script supprimé : $name" "database"
}

db_script_list() {
    db_query "SELECT id, name, category, description, path
              FROM scripts ORDER BY category, name;" "|"
}

db_script_get() {
    local name="$1"
    db_query "SELECT id, name, description, path, run_cmd, category
              FROM scripts WHERE name='${name}';" "|"
}

# ═══════════════════════════════════════════════════════════════════════
#  LOGS ACTIONS (dans SQLite en complément des fichiers)
# ═══════════════════════════════════════════════════════════════════════

db_log_action() {
    local action="$1"
    local module="${2:-system}"
    local status="${3:-ok}"
    local details="${4:-}"

    local safe_details="${details//\'/\'\'}"
    db_exec "INSERT INTO action_logs (action, module, status, details)
             VALUES ('${action}', '${module}', '${status}', '${safe_details}');" \
             2>/dev/null || true
}

db_log_list() {
    local limit="${1:-20}"
    db_query "SELECT timestamp, module, action, status
              FROM action_logs ORDER BY id DESC LIMIT ${limit};" "|"
}

# ═══════════════════════════════════════════════════════════════════════
#  STATISTIQUES GLOBALES
# ═══════════════════════════════════════════════════════════════════════

db_stats() {
    if ! db_available; then
        printf "  ${Y:-\e[33m}SQLite non disponible.${NC:-\e[0m}\n"
        return 0
    fi

    local nb_projects nb_github nb_notes nb_ssh nb_scripts nb_logs

    nb_projects=$(db_count "projects")
    nb_github=$(db_count "github_projects")
    nb_notes=$(db_count "notes")
    nb_ssh=$(db_count "ssh_hosts")
    nb_scripts=$(db_count "scripts")
    nb_logs=$(db_count "action_logs")

    printf "  ${B:-\e[34m}Projets locaux  :${NC:-\e[0m} %s\n" "$nb_projects"
    printf "  ${B:-\e[34m}Projets GitHub  :${NC:-\e[0m} %s\n" "$nb_github"
    printf "  ${B:-\e[34m}Notes           :${NC:-\e[0m} %s\n" "$nb_notes"
    printf "  ${B:-\e[34m}Hôtes SSH       :${NC:-\e[0m} %s\n" "$nb_ssh"
    printf "  ${B:-\e[34m}Scripts         :${NC:-\e[0m} %s\n" "$nb_scripts"
    printf "  ${B:-\e[34m}Actions loggées :${NC:-\e[0m} %s\n" "$nb_logs"
}

# ═══════════════════════════════════════════════════════════════════════
#  BACKUP / RESTAURATION BDD
# ═══════════════════════════════════════════════════════════════════════

db_backup() {
    local backup_dir="${CFG_BACKUPS_DIR:-$HOME/mon_env/backups}"
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${backup_dir}/env_${ts}.db"

    mkdir -p "$backup_dir"
    sqlite3 "$DB_FILE" ".backup '${backup_file}'" 2>/dev/null && {
        printf "  ${G:-\e[32m}✅ Backup BDD : %s${NC:-\e[0m}\n" "${backup_file/$HOME/~}"
        log_info "Backup BDD : $backup_file" "database"
    } || {
        printf "  ${R:-\e[31m}❌ Échec backup BDD${NC:-\e[0m}\n"
        log_error "Échec backup BDD" "database"
        return 1
    }
}

db_restore() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        ui_error "Fichier de backup introuvable : $backup_file"
        return 1
    fi

    # Sauvegarder l'actuel avant restauration
    db_backup

    cp "$backup_file" "$DB_FILE" && {
        printf "  ${G:-\e[32m}✅ Base restaurée depuis : %s${NC:-\e[0m}\n" \
               "${backup_file/$HOME/~}"
        log_info "BDD restaurée depuis : $backup_file" "database"
    } || {
        ui_error "Échec restauration"
        return 1
    }
}
