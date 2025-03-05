#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_FILE="$SCRIPT_DIR/restore-wp.conf"

LOGFILE="/var/log/restore-wp_$(whoami)_$(date +'%Y%m%d_%H%M%S').log"

echo "🔄 WordPress Restore Script"
echo "This script will restore your WordPress site from a backup."

if [[ -f "$CONFIG_FILE" ]]; then
    echo "🔹 Using configuration file: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "⚠️ No configuration file found. You can create '$CONFIG_FILE' to automate input values."
fi

log_action() {
  local result=$?
  local time_stamp
  time_stamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$time_stamp: $1: $2" | sudo tee -a "$LOGFILE" > /dev/null
  return $result
}

check_blank() {
  local value="$1"
  local var_name="$2"

  if [[ -z "$value" ]]; then
    echo "❌ Error: $var_name cannot be blank."
    log_action "Error" "$var_name cannot be blank."
    exit 1
  else
    echo "✅ $var_name is set to: $value"
  fi
}

if ! which wp > /dev/null; then
  errormsg="❌ WP CLI could not be found. Please install WP-CLI before running this script."
  echo "$errormsg"
  echo "ℹ️ For installation instructions, visit: https://wp-cli.org/#installing"
  log_action "ERROR" "$errormsg"
  exit 1
fi

backup_file="${BACKUP_FILE:-}"
if [[ -z "$backup_file" ]]; then
  read -p "📄 Enter the backup file path: " backup_file
fi
check_blank "$backup_file" "Backup file path"

restore_folder="${RESTORE_FOLDER:-}"
if [[ -z "$restore_folder" ]]; then
  read -p "📂 Enter the restore folder path: " restore_folder
fi
check_blank "$restore_folder" "Restore folder path"

if [[ ! -f "$backup_file" ]]; then
  echo "❌ Backup file $backup_file does not exist."
  log_action "ERROR" "Backup file does not exist."
  exit 1
fi
echo "📦 Backup file $backup_file exists."
log_action "CHECK" "Backup file is accessible"

if [[ ! -d "$restore_folder" ]]; then
  echo "📁 Restore folder $restore_folder does not exist. Creating it..."
  mkdir -p "$restore_folder" && sudo chown -R www-data:www-data "$restore_folder" || {
    echo "❌ Failed to create restore folder."
    log_action "ERROR" "Failed to create restore folder."
    exit 1
  }
fi
echo "📂 Restore folder $restore_folder is ready."

if [[ -f "$restore_folder/wp-config.php" ]]; then
  echo "⚠️ Existing WordPress installation detected."
  overwrite_setting="${OVERWRITE_EXISTING_WP:-ask}"
  case "$overwrite_setting" in
    "yes") echo "🔁 Overwriting existing installation." ;;
    "no") echo "❌ Restore aborted."; exit 1 ;;
    "ask"|"")
      read -p "❓ Overwrite existing WordPress installation? (yes/no): " confirm
      [[ "$confirm" != "yes" ]] && echo "❌ Restore aborted." && exit 1
      ;;
    *) echo "❌ Invalid OVERWRITE_EXISTING_WP value."; exit 1 ;;
  esac
fi

echo "📤 Extracting backup..."
sudo -u www-data tar --strip-components=1 -xzf "$backup_file" -C "$restore_folder" || {
  echo "❌ Failed to extract backup."
  log_action "ERROR" "Backup extraction failed."
  exit 1
}
echo "✅ Extraction complete."

cd "$restore_folder" || { echo "❌ Cannot access restore folder."; exit 1; }

if [[ ! -f "wp-config.php" ]]; then
  echo "❌ wp-config.php missing."
  log_action "ERROR" "wp-config.php missing."
  exit 1
fi

db_name=$(grep "DB_NAME" wp-config.php | awk -F", '" '{print $2}' | awk -F"'" '{print $1}')
db_user=$(grep "DB_USER" wp-config.php | awk -F", '" '{print $2}' | awk -F"'" '{print $1}')
db_pass=$(grep "DB_PASSWORD" wp-config.php | awk -F", '" '{print $2}' | awk -F"'" '{print $1}')

check_blank "$db_name" "Database name"
check_blank "$db_user" "Database user"
check_blank "$db_pass" "Database password"

drop_db_setting="${DROP_DATABASE_IF_EXISTS:-ask}"
if sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "USE \`$db_name\`;" 2>/dev/null; then
  case "$drop_db_setting" in
    "yes") echo "💣 Dropping $db_name...";;
    "no") echo "❌ Not dropping database."; drop_db_setting="no";;
    "ask"|"")
      read -p "❓ Drop existing database $db_name? (yes/no): " confirm
      [[ "$confirm" != "yes" ]] && echo "❌ Not dropping database." && drop_db_setting="no"
      ;;
    *) echo "❌ Invalid DROP_DATABASE_IF_EXISTS value."; exit 1 ;;
  esac

  if [[ "$drop_db_setting" == "yes" ]]; then
    sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "DROP DATABASE \`$db_name\`;"
    sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "CREATE DATABASE \`$db_name\`;"
    echo "✅ Database $db_name dropped and recreated."
  fi
else
  sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "CREATE DATABASE \`$db_name\`;"
  echo "✅ Database $db_name created."
fi

db_file="wordpress.sql"
if [[ -f "$db_file" ]]; then
  echo "📥 Restoring database..."
  sudo -u www-data wp db import "$db_file" || { echo "❌ Database restore failed."; exit 1; }
  sudo -u www-data rm -f "$db_file"
  echo "🧹 Removed database dump file: $db_file."
else
  echo "❌ Database dump not found."
  exit 1
fi

# Handle search and replace prompts
if [[ -z "$RUN_SEARCH_REPLACE" ]]; then
  read -p "❓ Run search and replace on the database? (yes/no/ask): " RUN_SEARCH_REPLACE
fi

if [[ "$RUN_SEARCH_REPLACE" == "ask" ]]; then
  read -p "🔍 Enter search string (e.g., https://appetiser.com.au): " SEARCH_STRING
  read -p "🔄 Enter replace string (e.g., https://dev.appetiser.com.au): " REPLACE_STRING
fi

if [[ "$RUN_SEARCH_REPLACE" == "yes" ]]; then
  sudo -u www-data wp search-replace "$SEARCH_STRING" "$REPLACE_STRING" --skip-columns=guid
  echo "✅ Search and replace completed."
fi

echo "🔧 Setting permissions..."
sudo chmod -R 755 "$restore_folder"
sudo chown -R www-data:www-data "$restore_folder"

echo "🎉 Restore complete!"
echo "📜 Log: $LOGFILE"
