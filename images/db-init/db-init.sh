#!/usr/bin/env bash
# Information Store initialisation on Azure SQL Managed Instance, mirroring ADT 3.2.2
# scripts/deploy initialize_sql_server (DB_USER_MANAGED=false, minus starting a server):
#   initialize_istore_database_for_sql_server + configure_istore_database
# Each step is recorded as a database extended property (i2aks.<step>) once it succeeds,
# so the Job is safe to re-run: completed steps are skipped, a failed step is retried.
# Secrets are read from files under /etc/i2secrets (Key Vault CSI).
set -euo pipefail

: "${DB_SERVER:?}" "${SA_USERNAME:?}"
export DB_PORT="${DB_PORT:-1433}" DB_NAME="${DB_NAME:-ISTORE}"
export DB_SSL_CONNECTION=true
export SQLCMD=/opt/mssql-tools/bin/sqlcmd SQLCMD_FLAGS="-N -b"
export GENERATED_DIR=/opt/databaseScripts/generated
# ADT default user names (utils/common_variables.sh)
export DBA_USERNAME=dba DBB_USERNAME=dbb I2_ETL_USERNAME=i2etl ETL_USERNAME=etl \
  I2_ANALYZE_USERNAME=i2analyze I2_PUBLIC_USERNAME=i2_public
SECRETS=/etc/i2secrets
SA_PW="$(<"${SECRETS}/SA_PASSWORD")"
DBA_PW="$(<"${SECRETS}/DBA_PASSWORD")"
declare -A USER_PW=(
  [dbb]="$(<"${SECRETS}/DBB_PASSWORD")"
  [i2analyze]="$(<"${SECRETS}/I2ANALYZE_PASSWORD")"
  [i2etl]="$(<"${SECRETS}/I2ETL_PASSWORD")"
  [etl]="$(<"${SECRETS}/ETL_PASSWORD")"
)
# The db-scripts pick SA_*, then ADMIN_*, then DB_* credentials; clear what the image set.
unset SA_PASSWORD ADMIN_USERNAME ADMIN_PASSWORD DB_USERNAME DB_PASSWORD DB_ROLE

log() { echo ">>> $*"; }
# as <user> <password> <command...>   - run an ADT script with DB_* credentials
as() { local u="$1" p="$2"; shift 2; DB_USERNAME="$u" DB_PASSWORD="$p" "$@"; }
sa_sql() { "${SQLCMD}" ${SQLCMD_FLAGS} -S "${DB_SERVER},${DB_PORT}" -U "${SA_USERNAME}" -P "${SA_PW}" -h -1 -W "$@"; }

db_exists() { [[ "$(sa_sql -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'${DB_NAME}'" | tr -d '[:space:]')" == 1 ]]; }
step_done() {
  db_exists && [[ "$(sa_sql -d "${DB_NAME}" -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.extended_properties WHERE class = 0 AND name = N'i2aks.$1'" | tr -d '[:space:]')" == 1 ]]
}
mark_done() { sa_sql -d "${DB_NAME}" -Q "EXEC sp_addextendedproperty @name = N'i2aks.$1', @value = N'done'" >/dev/null; }
step() { # name command...
  local name="$1"; shift
  if step_done "${name}"; then log "skip ${name} (done)"; return; fi
  log "${name}"
  "$@"
  mark_done "${name}"
}

create_database() {
  if db_exists; then log "database ${DB_NAME} exists"; return; fi
  # ADT runs the generated creation script as SA. Managed Instance manages data/log
  # files itself, so if that script cannot run here fall back to a plain CREATE DATABASE
  # (instance collation applies).
  if ! as "${SA_USERNAME}" "${SA_PW}" "${GENERATED_DIR}/runDatabaseCreationScripts.sh" || ! db_exists; then
    if db_exists; then
      echo "Generated creation script failed after creating ${DB_NAME}; inspect it before re-running" >&2
      exit 1
    fi
    log "generated creation script not usable on Managed Instance - CREATE DATABASE [${DB_NAME}] + IS schemas"
    sa_sql -Q "CREATE DATABASE [${DB_NAME}]"
    # create_dba_login_and_user.sh grants on these straight after creation (ADT's SCHEMAS list)
    local schema
    for schema in IS_Meta IS_Data IS_FP IS_Public IS_WC IS_Vq IS_Core IS_Staging IS_Stg; do
      sa_sql -d "${DB_NAME}" -Q "IF SCHEMA_ID(N'${schema}') IS NULL EXEC(N'CREATE SCHEMA [${schema}]')"
    done
  fi
}

create_dba() {
  SA_USERNAME="${SA_USERNAME}" SA_PASSWORD="${SA_PW}" DB_USERNAME="${DBA_USERNAME}" DB_PASSWORD="${DBA_PW}" \
    DB_ROLE="${DBA_USERNAME}_role" /opt/db-scripts/create_dba_login_and_user.sh
}

create_login() { # user role
  ADMIN_USERNAME="${DBA_USERNAME}" ADMIN_PASSWORD="${DBA_PW}" DB_USERNAME="$1" DB_PASSWORD="${USER_PW[$1]}" \
    DB_ROLE="$2" /opt/db-scripts/create_db_login_and_user.sh
}

add_to_role() { # user role
  ADMIN_USERNAME="${DBA_USERNAME}" ADMIN_PASSWORD="${DBA_PW}" DB_USERNAME="$1" DB_PASSWORD="${USER_PW[$1]}" \
    DB_ROLE="$2" /opt/db-scripts/add_user_to_db_role.sh
}

create_database   # marker lives in the database, so this step checks existence instead
step create_dba          create_dba
step create_db_roles     as "${DBA_USERNAME}" "${DBA_PW}" /opt/db-scripts/create_db_roles.sh
step grant_permissions   as "${DBA_USERNAME}" "${DBA_PW}" /opt/db-scripts/grant_permissions_to_roles.sh
step login_dbb           create_login dbb db_backupoperator
step login_i2analyze     create_login i2analyze i2analyze_role
step login_i2etl         create_login i2etl i2etl_role
step login_etl           create_login etl etl_role
step etl_sysadmin        as "${DBA_USERNAME}" "${DBA_PW}" /opt/db-scripts/add_etl_user_to_sys_admin_role.sh
step static_scripts      as "${DBA_USERNAME}" "${DBA_PW}" "${GENERATED_DIR}/runStaticScripts.sh"
step dynamic_scripts     as "${DBA_USERNAME}" "${DBA_PW}" "${GENERATED_DIR}/runDynamicScripts.sh"
step role_i2_public      add_to_role i2analyze i2_public_role
step role_deletion_rule  add_to_role i2etl deletion_by_rule
log "Information Store ${DB_NAME} initialised on ${DB_SERVER}"
