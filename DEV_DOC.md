# Developer documentation for Inception project by ozamora-

This file explains, in clear and simple terms, how a developer can:
* Set up the environment from scratch (prerequisites, configuration files, secrets).
* Build and launch the project using the Makefile and Docker Compose.
* Use relevant commands to manage the containers and volumes.
* Identify where the project data is stored and how it persists.

---

## Index
- [Development Environment](#development-environment)
	- [Prerequisites](#prerequisites)
	- [Configuration Files](#configuration-files)
	- [Secrets](#secrets)
- [Build and Launch](#build-and-launch)
	- [Makefile](#makefile)
	- [Docker Compose](#docker-compose)
- [Container and Volume Management](#container-and-volume-management)
- [Data Storage and Persistence](#data-storage-and-persistence)

---

## Development Environment

### Prerequisites
Before setting up the environment, ensure the host system meets the following software requirements:
*   **Operating System:** Debian 12 (Bookworm) is the target host operating system (typically running inside VirtualBox with at least 15 GB of virtual storage and 2 GB of RAM).
*   **Docker Engine:** Version 20.10+ installed and running.
*   **Docker Compose:** Version 2.20+ (using the modern `docker compose` plugin syntax, not the deprecated standalone `docker-compose`).
*   **GNU Make:** Version 4.3+ for build automation.
*   **OpenSSL:** Utilized in the host or during image builds to manage cryptographic certificate generation.

### Configuration Files
The configuration files are strictly decoupled across services inside the `srcs/requirements/` directory structure:
1.  **NGINX Configuration (`srcs/requirements/nginx/conf/nginx.conf`):**
    *   Configured to listen exclusively on port `443` using SSL.
    *   Restricts cryptographic negotiations to `ssl_protocols TLSv1.2 TLSv1.3;`.
    *   Sets up the reverse proxy route for PHP processing via a FastCGI directive targeting `wordpress:9000`.
2.  **WordPress Pool Configuration (`srcs/requirements/wordpress/conf/www.conf`):**
    *   Configures PHP-FPM 8.2 to listen on a TCP port `9000` (instead of a default local UNIX socket), allowing network communication across containers.
    *   Runs the FPM workers under the restricted user/group `www-data`.
3.  **MariaDB Configuration (`srcs/requirements/mariadb/conf/50-server.cnf`):**
    *   Binds the MySQL daemon to `bind-address = 0.0.0.0` to accept remote TCP connections from the WordPress container.
    *   Estandariza los directorios de socket y PID en `/run/mysqld/` de acuerdo con las especificaciones de Debian Bookworm.

### Secrets
To guarantee that no credentials, API keys, or passwords are leaked to the public Git repository, we utilize **Docker Secrets** combined with a local `.gitignore` strategy:
*   **Storage on Host:** All secrets are stored in raw text files in the `secrets/` directory in the root of the project:
    *   `secrets/db_password.txt` (Password for the WordPress SQL database user).
    *   `secrets/db_root_password.txt` (Password for the MariaDB database root administrator).
*   **Git Protection:** The `.gitignore` file explicitly includes `secrets/` and `srcs/.env` to prevent them from being committed to version control.
*   **Runtime Mounting:** Docker Compose mounts these files as virtual temporary read-only files inside the memory-backed filesystem (`tmpfs`) of the containers under `/run/secrets/db_password` and `/run/secrets/db_root_password`.
*   **Script Access:** Initialization scripts (`init_db.sh` and `setup_wordpress.sh`) extract these keys securely at boot time:
    ```bash
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
    ```

---

## Build and Launch

### Makefile
The automation of the environment lifecycle is handled entirely by the `Makefile` in the root directory. It contains rules designed to safely initialize directories on the host under your user login home directory before launching Docker:

*   `make` (or `make all`): Automatically creates host storage directories (`/home/ozamora-/data/wordpress` and `/home/ozamora-/data/mariadb`), builds the custom Docker images, and launches the stack in detached mode.
*   `make build`: Compiles the custom Docker images without launching the containers.
*   `make up`: Starts previously compiled services in detached mode (`-d`).
*   `make down`: Gracefully stops the containers without deleting persistent volume directories.
*   `make clean`: Stops and removes the active project containers, networks, and internal Docker-built images.
*   `make fclean`: Triggers a deep cleanup. It executes `make clean`, purges the local volume directories from the host using `sudo rm -rf`, and cleans the global Docker cache with `docker system prune -af`.
*   `make re`: Performs a complete rebuild from scratch by executing `make fclean` followed by `make all`.

### Docker Compose
The `docker-compose.yml` file acts as the infrastructure orchestrator, defining:
1.  **Network Isolation:** A custom network of type `bridge` called `inception_network`.
2.  **Service Linkage:** Services connect only through this isolated network. They communicate using internal Docker DNS (e.g., WordPress connects to `mariadb:3306`).
3.  **Volume Bind Mounts:** Maps the persistent database and application directories of the containers back to `/home/ozamora-/data/` on the host to ensure absolute data persistence.

---

## Container and Volume Management

Developers can inspect and debug the running stack using standard Docker CLI tools:

*   **View Running Containers:**
    ```bash
    docker ps
    ```
*   **Inspect Logs in Real Time (For debugging script errors):**
    ```bash
    docker logs -f wordpress
    docker logs -f mariadb
    docker logs -f nginx
    ```
*   **Execute Commands inside a Container (e.g., checking PHP runtime):**
    ```bash
    docker exec -it wordpress php -v
    ```
*   **Verify Volume Mount Points:**
    ```bash
    docker volume ls
    docker volume inspect srcs_mariadb_data
    ```
*   **Verify Active Networks:**
    ```bash
    docker network ls
    docker network inspect inception_network
    ```

---

## Data Storage and Persistence

Data persistence is implemented using **local bind mounts** to ensure files are retained even when containers are destroyed:

1.  **WordPress Core and Uploads:**
    *   **Host Path:** `/home/ozamora-/data/wordpress`
    *   **Container Path (WordPress & NGINX):** `/var/www/html`
    *   *Note:* Sharing this path via a volume allows WordPress to write media, plugins, and core files, while NGINX reads them directly to serve CSS, JS, and images without proxying static assets through PHP.
2.  **MariaDB SQL Data:**
    *   **Host Path:** `/home/ozamora-/data/mariadb`
    *   **Container Path (MariaDB):** `/var/lib/mysql`
    *   *Note:* The database folder contains critical database configurations, users, and tables. Since it is mapped to a host path, your SQL data remains intact across `docker compose down` commands.
