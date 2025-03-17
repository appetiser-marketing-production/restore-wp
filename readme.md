# 🛠️ WordPress Restore Script (`restore-wp.sh`)

This script restores a WordPress site from a backup archive created by the `backup-wp.sh` script. It automates restoring site files and the database, with safety checks and logging for reliable recovery.

---

## 📝 Version Information
- **Version:** 1.2.0
- **Author:** Landing Page Team
- **Author URI:** [https://appetiser.com.au/](https://appetiser.com.au/)

🔄 Changes in Version 1.2.1
🔧 configuration file adjustment. it is now available for prompt if you want to use another other than the default
🔒 Added dbname and table prefix updates.

🔄 Changes in Version 1.2.0
- 🔄 **Search and Replace feature** after database import.
  - Configurable via `restore-wp.conf` with:
    ```bash
    RUN_SEARCH_REPLACE="yes"
    SEARCH_STRING="https://appetiser.com.au"
    REPLACE_STRING="https://dev.appetiser.com.au"
    ```
  - Supports automatic or prompted execution for replacing URLs or strings during restores.
- 📝 **Prompts added** for missing `RUN_SEARCH_REPLACE`, `SEARCH_STRING`, and `REPLACE_STRING` if not set in config.
- 🔧 All previous improvements from v1.1.0 remain.

🔄 Changes in Version 1.1.0
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
9. 🔄 (Optional) Runs a search and replace on the restored database to update URLs or strings.
10. 🧹 Removes the database dump after import.
11. 🔧 Resets permissions on restored files.
12. 📜 Logs all actions.

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

# Run search and replace after restore
# Options: yes, no, ask
RUN_SEARCH_REPLACE="ask"

# What to search for (only if RUN_SEARCH_REPLACE is yes or ask)
SEARCH_STRING="https://appetiser.com.au"

# What to replace it with (only if RUN_SEARCH_REPLACE is yes or ask)
REPLACE_STRING="https://dev.appetiser.com.au"
