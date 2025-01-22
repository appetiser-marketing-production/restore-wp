# Restore WordPress Site Script (`restore-wp`)

## Introduction

The `restore-wp` script is designed to restore a WordPress site from a backup archive created by the `backup-wp` script. This script automates the restoration of WordPress files and the database, ensuring that your website is fully functional after the process. It includes robust logging and error handling for a seamless restore experience.

---

## Prerequisites

Before using the script, ensure the following requirements are met:

1. **WP-CLI Installed**:
   - WP-CLI must be installed and available in your system's PATH.
   - [WP-CLI Installation Instructions](https://wp-cli.org/#installing)

2. **Backup File**:
   - A `.tar.gz` backup archive created using the `backup-wp` script, containing the WordPress site files and `wordpress.sql` database dump.

3. **Permissions**:
   - Ensure you have proper permissions to access the restore folder and manipulate the database.
   - The script should be executed as a user with `sudo` privileges or as the user who owns the WordPress files.

---

## Steps Performed by the Script

The script performs the following actions:

1. **Input Validation**:
   - Verifies the existence and readability of the specified backup file.
   - Checks the restore folder's existence or creates it if necessary.

2. **Extract Backup Archive**:
   - Decompresses the `.tar.gz` archive into the specified restore folder.

3. **Database Restoration**:
   - Locates the `wordpress.sql` file in the extracted backup.
   - Uses WP-CLI to import the database dump into the WordPress database.

4. **Logging**:
   - Logs all actions and errors to a file in `/var/log` for auditing and troubleshooting.

---

## Usage

### Command-Line Arguments:

```bash
./restore-wp <backup_file> <restore_folder>
