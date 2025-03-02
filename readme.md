# 🛠️ WordPress Restore Script (`restore-wp.sh`)

This script restores a WordPress site from a backup archive created by the `backup-wp.sh` script. It automates restoring site files and the database, with safety checks and logging for reliable recovery.

---

## 📝 Version Information
- **Version:** 1.1.0
- **Author:** Landing Page Team
- **Author URI:** [https://appetiser.com.au/](https://appetiser.com.au/)

### 🎉 What's New in Version 1.1.0
- 🔧 **Configuration file support (`restore-wp.conf`)** for unattended runs.
- 💣 **Full database drop option** via `DROP_DATABASE_IF_EXISTS` setting (`yes`, `no`, `ask`).
- ⚠️ **WordPress installation overwrite check** via `OVERWRITE_EXISTING_WP` setting.
- 🧹 **Automatic cleanup of the database dump file** after restore.
- 🎨 Improved logging, feedback, and user prompts.

---

## 🔧 Prerequisites
Before running the script, ensure:
1. **WP-CLI installed**  
   - [WP-CLI Installation Instructions](https://wp-cli.org/#installing)

2. **Proper permissions**  
   - The script uses `www-data` for file and database operations.  
   - Ensure the user running the script has `sudo` privileges.

3. **Backup file**  
   - Must be a `.tar.gz` archive created by `backup-wp.sh`.

4. **Logging directory**  
   - Logs are saved to `/var/log/`.

---

## 🛠️ What the Script Does
1. ✅ Validates and loads values from `restore-wp.conf` or prompts if missing.
2. 📦 Verifies the backup file and restore folder.
3. ⚠️ Detects existing WordPress installations and prompts or acts based on config.
4. 📤 Extracts the backup archive (silently).
5. 🔑 Extracts database credentials from `wp-config.php`.
6. 💣 Drops the existing database if configured or confirmed.
7. 🏗️ Creates the database if missing.
8. 📥 Imports the `wordpress.sql` database dump.
9. 🧹 Removes the database dump after import.
10. 🔧 Resets permissions on restored files.
11. 📜 Logs all actions.

---

## ⚙️ Configuration File (`restore-wp.conf`)

Create `restore-wp.conf` in the same directory as `restore-wp.sh` to automate values:

```bash
# Path to the backup file
BACKUP_FILE="/home/user/backups/site_backup.tar.gz"

# Path to restore folder
RESTORE_FOLDER="/var/www/html"

# Overwrite existing WordPress installation
# Options: yes, no, ask
OVERWRITE_EXISTING_WP="ask"

# Drop existing database
# Options: yes, no, ask
DROP_DATABASE_IF_EXISTS="ask"
