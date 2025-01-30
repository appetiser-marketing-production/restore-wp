#!/bin/bash

# Restore script for staging site
echo "Usage: $0 <backup-file> <restore-folder>"
echo "This script will restore the WordPress site files and database from a specified backup file."

LOGFILE="/var/log/restore-wp_$(whoami)_$(date +'%Y%m%d_%H%M%S').log"

log_action() {
  local result=$?
  local time_stamp
  time_stamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$time_stamp: $1: $2" | sudo tee -a "$LOGFILE" > /dev/null
  return $result
}

# Function to check if a variable is blank
check_blank() {
  local value="$1"
  local var_name="$2"

  case "$value" in
    "")
      echo "Error: $var_name cannot be blank. Please provide a valid $var_name."
      log_action "Error" "$var_name cannot be blank. Please provide a valid $var_name."
      exit 1
      ;;
    *)
      echo "$var_name is set to: $value"
      ;;
  esac
}

# Check if wp-cli is installed
if ! which wp > /dev/null; then
  errormsg="WP CLI could not be found. Please install WP-CLI before running this script."
  echo "$errormsg"
  echo "For installation instructions, visit: https://wp-cli.org/#installing"
  log_action "ERROR" "$errormsg"
  exit 1
fi

# Backup file and restore folder
backup_file=${1:-$(read -p "Enter the backup file path: " tmp && echo "$tmp")}
# Check for blanks
check_blank "$backup_file" "Backup file path"

# Check if backup file exists
case "$(test -f "$backup_file" && echo "exists" || echo "not_exists")" in
  "exists")
    echo "Backup file $backup_file exists."
    log_action "CHECK" "Backup file is accessible"
    ;;
  "not_exists")
    errormsg="Error: Backup file $backup_file does not exist."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
  *)
    errormsg="Unexpected error occurred while checking the backup file."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

restore_folder=${2:-$(read -p "Enter the restore folder path: " tmp && echo "$tmp")}
check_blank "$restore_folder" "Restore folder path"


# Check if restore folder exists, create if not
case "$(test -d "$restore_folder" && echo "exists" || echo "not_exists")" in
  "exists")
    echo "Restore folder $restore_folder exists."
    log_action "CHECK" "Restore folder is accessible"
    ;;
  "not_exists")
    echo "Restore folder $restore_folder does not exist. Creating it..."
    mkdir -p "$restore_folder" && sudo chown -R www-data:www-data "$restore_folder" && log_action "INFO" "Restore folder $restore_folder created and owned by www-data." || {
      errormsg="Error: Failed to create or set ownership for restore folder $restore_folder."
      echo "$errormsg"
      log_action "ERROR" "$errormsg"
      exit 1
    }
    ;;
  *)
    errormsg="Unexpected error occurred while checking the restore folder."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

# Extract backup file
echo "Extracting backup file..."
extract_status=$(sudo -u www-data tar --strip-components=1 -xzvf "$backup_file" -C "$restore_folder" > /dev/null 2>&1 && echo "success" || echo "failure")

case "$extract_status" in
  "success")
    msg="Backup file successfully extracted to $restore_folder."
    echo "$msg"
    log_action "DONE" "$msg"
    ;;
  "failure")
    errormsg="Error: Failed to extract backup file $backup_file."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
  *)
    errormsg="Unexpected error occurred during extraction."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

# Navigate to the restore folder
cd "$restore_folder" || {
      errormsg="Error: Failed to navigate to restore folder $restore_folder."
      echo "$errormsg"
      log_action "ERROR" "$errormsg"
      exit 1
    }
errormsg="Successfully navigated to restore folder $restore_folder."
echo "$errormsg"
log_action "Success:" "$errormsg"

# Extract database credentials from wp-config.php
db_name=$(grep "DB_NAME" "$restore_folder/wp-config.php" | cut -d \' -f 4)
db_user=$(grep "DB_USER" "$restore_folder/wp-config.php" | cut -d \' -f 4)
db_pass=$(grep "DB_PASSWORD" "$restore_folder/wp-config.php" | cut -d \' -f 4)

# Validate extraction using case statements
case "$db_name" in
  "")
    echo "Error: Could not extract database name from wp-config.php."
    log_action "ERROR" "Could not extract database name from wp-config.php."
    exit 1
    ;;
  *)
    echo "Database name: $db_name"
    ;;
esac

case "$db_user" in
  "")
    echo "Error: Could not extract database user from wp-config.php."
    log_action "ERROR" "Could not extract database user from wp-config.php."
    exit 1
    ;;
  *)
    echo "Database user: $db_user"
    ;;
esac

case "$db_pass" in
  "")
    echo "Error: Could not extract database password from wp-config.php."
    log_action "ERROR" "Could not extract database password from wp-config.php."
    exit 1
    ;;
  *)
    echo "Database password extracted successfully."
    ;;
esac

# Create the database if it doesn't exist
echo "Ensuring the database $db_name exists..."
if sudo -u www-data bash -c "mysql -u'$db_user' -p'$(echo "$db_pass")' -e \"CREATE DATABASE IF NOT EXISTS \\\`$db_name\\\`;\" 2>/dev/null"; then
  create_db_status="success"
else
  create_db_status="failure"
fi

# Check database creation status using case statement
case "$create_db_status" in
  "success")
    msg="Database $db_name successfully created or already exists."
    echo "$msg"
    log_action "DONE" "$msg"
    ;;
  "failure")
    errormsg="Error: Failed to create database $db_name."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
  *)
    errormsg="Unexpected error: Database creation status unknown."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

# Restore database
db_file="$restore_folder/wordpress.sql"

case "$(test -f "$db_file" && echo "exists" || echo "not_exists")" in
  "exists")
    msg="Database dump file $db_file exists. Restoring database..."
    echo "$msg"
    log_action "Check" "$msg"

    # Capture output of the command for logging
    restore_output=$(sudo -u www-data wp db import "$db_file" 2>&1)
    restore_status=$?

    if [ $restore_status -eq 0 ]; then
      msg="Database successfully restored from $db_file."
      echo "$msg"
      log_action "DONE" "$msg"
    else
      errormsg="Error: Failed to restore database from $db_file. Details: $restore_output"
      echo "$errormsg"
      log_action "ERROR" "$errormsg"
      exit 1
    fi
    ;;
  "not_exists")
    errormsg="Database dump file $db_file does not exist in the extracted backup."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
  *)
    errormsg="Unexpected error occurred while checking the database dump file."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

# Cleanup database dump file
case "$(test -f "$db_file" && echo "exists" || echo "not_exists")" in
  "exists")
    echo "Cleaning up database dump file: $db_file"
    rm -f "$db_file"
    case "$?" in
      0)
        msg="Database dump file $db_file successfully removed."
        echo "$msg"
        log_action "DONE" "$msg"
        ;;
      *)
        errormsg="Error: Failed to remove database dump file $db_file."
        echo "$errormsg"
        log_action "ERROR" "$errormsg"
        ;;
    esac
    ;;
  "not_exists")
    echo "Database dump file $db_file does not exist, no cleanup needed."
    log_action "INFO" "Database dump file $db_file does not exist, no cleanup needed."
    ;;
  *)
    errormsg="Unexpected error while checking database dump file $db_file."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    ;;
esac

# Set permissions
echo "Setting permissions for the restored files..."
chmod_status=$(sudo chmod -R 755 "$restore_folder" && sudo chown -R www-data:www-data "$restore_folder" && echo "success" || echo "failure")

case "$chmod_status" in
  "success")
    msg="Permissions set successfully for $restore_folder."
    echo "$msg"
    log_action "DONE" "$msg"
    ;;
  "failure")
    errormsg="Error: Failed to set permissions for $restore_folder."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
  *)
    errormsg="Unexpected error occurred while setting permissions."
    echo "$errormsg"
    log_action "ERROR" "$errormsg"
    exit 1
    ;;
esac

echo "Restore complete. Files restored to $restore_folder and database imported."
echo "Log file created at: $LOGFILE"
