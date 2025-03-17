#!/bin/bash

# Restore script for sites archived through backup-wp shell script.

echo "🔄 WordPress Restore Script"
echo "This script will restore your WordPress site from a backup."

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_FILE="${1:-$SCRIPT_DIR/restore-wp.conf}"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "🔹 Using configuration file: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "⚠️ No configuration file found. Using default settings or prompting for input."
fi

LOGFILE="/var/log/restore-wp_$(whoami)_$(date +'%Y%m%d_%H%M%S').log"

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

#Ensure config values are loaded or prompt if missing
backup_file="${BACKUP_FILE:-$(read -p "📄 Enter the backup file path: " tmp && echo "$tmp")}"
check_blank "$backup_file" "Backup file path"

base_folder="${BASE_FOLDER:-$(read -p "📂 Enter the base folder path (e.g., /var/www/work/): " tmp && echo "$tmp")}"
check_blank "$base_folder" "Base folder path"

restore_folder="${RESTORE_FOLDER:-$(read -p "📂 Enter the site folder name: " tmp && echo "$tmp")}"
check_blank "$restore_folder" "Restore folder name"

# Combine base folder and restore folder
full_restore_path="${base_folder%/}/${restore_folder}"


backup_file="${BACKUP_FILE:-}"
if [[ -z "$backup_file" ]]; then
  read -p "📄 Enter the backup file path: " backup_file
fi
check_blank "$backup_file" "Backup file path"

if [[ ! -f "$backup_file" ]]; then
  echo "❌ Backup file $backup_file does not exist."
  log_action "ERROR" "Backup file does not exist."
  exit 1
fi
echo "📦 Backup file $backup_file exists."
log_action "CHECK" "Backup file is accessible"

if [[ ! -d "$full_restore_path" ]]; then
  echo "📁 Restore folder $full_restore_path does not exist. Creating it..."
  mkdir -p "$full_restore_path" && sudo chown -R www-data:www-data "$full_restore_path" || {
    echo "❌ Failed to create restore folder."
    log_action "ERROR" "Failed to create restore folder."
    exit 1
  }
fi
echo "📂 Restore folder $full_restore_path is ready."

if [[ -f "$full_restore_path/wp-config.php" ]]; then
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
sudo -u www-data tar --strip-components=1 -xzf "$backup_file" -C "$full_restore_path" || {
  echo "❌ Failed to extract backup."
  log_action "ERROR" "Backup extraction failed."
  exit 1
}
echo "✅ Extraction complete."

cd "$full_restore_path" || { echo "❌ Cannot access restore folder."; exit 1; }

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

# Prompt or use config value for changing DB name
if [[ -z "$CHANGE_DBNAME" ]]; then
  read -p "❓ Change the database name? (yes/no/ask): " CHANGE_DBNAME
fi

if [[ "$CHANGE_DBNAME" == "ask" ]]; then
  read -p "❓ Rename database to ${restore_folder}db? (yes/no): " confirm
  [[ "$confirm" == "yes" ]] && CHANGE_DBNAME="yes" || CHANGE_DBNAME="no"
fi

if [[ "$CHANGE_DBNAME" == "yes" ]]; then
  #Update database name and table prefix
  new_db_name="${restore_folder}db"

  echo "🔄 Updating WordPress database name and table prefix..."
  # Rename the database in MySQL
  echo "🔄 Renaming database from $db_name to $new_db_name..."
  # Create the new database
  sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "CREATE DATABASE \`$new_db_name\`;"
  # Copy all data from old DB to new DB
  sudo -u www-data mysqldump -u"$db_user" -p"$db_pass" "$db_name" | sudo -u www-data mysql -u"$db_user" -p"$db_pass" "$new_db_name"
  # Update wp-config.php to use the new database
  sudo -u www-data wp config set DB_NAME "'$new_db_name'" --raw --type=constant
  echo "✅ Database renamed successfully."
  sudo -u www-data mysql -u"$db_user" -p"$db_pass" -e "DROP DATABASE \`$db_name\`;"
  echo "✅ Database name set to $new_db_name"
else
  new_db_name="$db_name"
fi

# Prompt or use config value for updating table prefix
if [[ -z "$UPDATE_PREFIX" ]]; then
  read -p "❓ Update table prefix? (yes/no/ask): " UPDATE_PREFIX
fi

if [[ "$UPDATE_PREFIX" == "ask" ]]; then
  read -p "❓ Change table prefix to ${restore_folder}_? (yes/no): " confirm
  [[ "$confirm" == "yes" ]] && UPDATE_PREFIX="yes" || UPDATE_PREFIX="no"
fi

if [[ "$UPDATE_PREFIX" == "yes" ]]; then
  # Rename all tables in MySQL to use the new prefix
  old_table_prefix=$(grep "\$table_prefix" wp-config.php | awk -F "'" '{print $2}')
  new_table_prefix="${restore_folder}_"

  echo "🔄 Changing table prefix from $old_table_prefix to $new_table_prefix..."
  # Get all tables with the old prefix
  tables=$(sudo -u www-data mysql -u"$db_user" -p"$db_pass" -D "$new_db_name" -e "SHOW TABLES LIKE '${old_table_prefix}%';" | grep "$old_table_prefix")
  # Rename each table
  for table in $tables; do
      new_table="${new_table_prefix}${table#$old_table_prefix}"
      sudo -u www-data mysql -u"$db_user" -p"$db_pass" -D "$new_db_name" -e "RENAME TABLE \`$table\` TO \`$new_table\`;"
      echo "✅ Renamed $table → $new_table"
  done
  # Update wp-config.php to use the new table prefix
  sudo -u www-data wp config set table_prefix "$new_table_prefix" --type=variable

  # Update usermeta and options table to use the new prefix
  echo "🔄 Updating WordPress user permissions and settings to match new prefix..."

  sudo -u www-data mysql -u"$db_user" -p"$db_pass" -D "$new_db_name" -e "
    UPDATE ${new_table_prefix}options 
    SET option_name = REPLACE(option_name, '${old_table_prefix}', '${new_table_prefix}')
    WHERE option_name LIKE '${old_table_prefix}%';

    UPDATE ${new_table_prefix}usermeta 
    SET meta_key = REPLACE(meta_key, '${old_table_prefix}', '${new_table_prefix}')
    WHERE meta_key LIKE '${old_table_prefix}%';
  "
  echo "✅ Database prefix updated in wp_options and wp_usermeta."
  echo "✅ Table prefix set to $new_table_prefix"
fi

echo "🔧 Setting permissions..."
sudo chmod -R 755 "$full_restore_path"
sudo chown -R www-data:www-data "$full_restore_path"

echo "🎉 Restore complete!"
echo "📜 Log: $LOGFILE"