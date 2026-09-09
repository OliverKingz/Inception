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
*   **Operating System:** Linux-based distribution with a kernel version that supports Docker.
*   **Docker Engine:** installed and running.
*   **Docker Compose:** using the modern `docker compose` plugin syntax, not the deprecated standalone `docker-compose`.
*   **GNU Make:** installed to utilize the provided Makefile for automation.
*   **Git:** installed to clone the repository.

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
	*   Standarizes the data directory to `/var/lib/mysql` for compatibility with the persistent volume mount.

### Secrets
To guarantee that no credentials, API keys, or passwords are leaked to the public Git repository, we utilize **Docker Secrets** combined with a local `.gitignore` strategy:
*   **Storage on Host:** All secrets are stored in raw text files in the `secrets/` directory in the root of the project:
    *   `secrets/MYSQL_PASSWORD.txt` (Password for the SQL database user).
    *   `secrets/MYSQL_ROOT_PASSWORD.txt` (Password for the SQL database root administrator).
	*   `secrets/WP_ADMIN_PASSWORD.txt` (Password for the WordPress admin user).
	*   `secrets/WP_USER_PASSWORD.txt` (Password for the WordPress user).
*   **Git Protection:** The `.gitignore` file explicitly includes `secrets/` and `srcs/.env` to prevent them from being committed to version control.
*   **Runtime Mounting:** Docker Compose mounts these files as virtual temporary read-only files inside the memory-backed filesystem (`tmpfs`) of the containers under `/run/secrets/MYSQL_PASSWORD` and `/run/secrets/MYSQL_ROOT_PASSWORD`.
*   **Script Access:** Initialization scripts (`init_db.sh` and `setup_wordpress.sh`) extract these keys securely at boot time:
    ```bash
    MYSQL_PASSWORD=$(cat /run/secrets/MYSQL_PASSWORD)
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/MYSQL_ROOT_PASSWORD)
    ```

At the start of the evaluation, the evaluator must create these secret files with the correct passwords in the `secrets/` directory before running `make all`. The Makefile will fail if any of these secrets are missing.

``` bash
echo "<STRONG_PASSWORD>" > secrets/MYSQL_PASSWORD.txt
echo "<STRONG_PASSWORD>" > secrets/MYSQL_ROOT_PASSWORD.txt
echo "<STRONG_PASSWORD>" > secrets/WP_ADMIN_PASSWORD.txt
echo "<STRONG_PASSWORD>" > secrets/WP_USER_PASSWORD.txt
```
About the `.env` file, it is used to define environment variables for the Docker Compose stack. It contains variables that are referenced in the `docker-compose.yml` file, and the other scripts. 
A default `.env.example` file is provided in the `srcs/` directory. Developers should copy it to `srcs/.env` and modify the values as needed for their local environment.
> 🔒 **Security Notice:** Both the `srcs/.env` file and the `secrets/` folder are listed in `.gitignore`. They will **never** be uploaded to GitHub, which is a strict rule to pass the project.

---

## Build and Launch

### Makefile

Main rules for managing the project lifecycle:
* `make all` (or `make`): Automatically creates host storage directories for WordPress and MariaDB, builds the custom Docker images, and launches the stack in detached mode.
* `make env`: Creates the `.env` file with default environment variables if it doesn't exist.
* `make dirs`: Creates the necessary directories for persistent data storage on the host machine.
* `make build`: Compiles the custom Docker images without launching the containers.
* `make up`: Starts previously compiled services in detached mode (`-d`). It also waits for the services to be fully ready before returning control to the terminal.
* `make down`: Gracefully stops the containers without deleting persistent volume directories.
* `make start`: Starts the containers without rebuilding them.
* `make stop`: Stops the containers without deleting them.
* `make restart`: Stops and then starts the containers.

Rules for displaying information and logs
* `make images`: Lists the Docker images that have been built for the project.
* `make ps`: Lists the running containers and their status.
* `make status`: Displays the status of the images and running containers.
* `make logs`: Displays the logs of all containers in real-time.
* `make logs-<service>`: Displays the logs of a specific service (e.g., `make logs-wordpress`).

Rules for checking the health of the services, database, network and containers:
* `make db-check`: Displays the list of databases in MariaDB, users and their grants (permissions and privileges). 
* `make wp-check`: Displays the list of users and their roles in WordPress. Also the URL.
* `make nginx-check`: Checks the syntax of the NGINX configuration files and reports any errors or warnings.
* `make network-check`: Inspects the Docker network created by docker-compose to ensure that all containers are connected properly.
* `make ls-containers`: Lists the critical directories for each running container.

Rules for rebuilding services preserving persistent data:
* `make rebuild-all`: Rebuilds all the services, useful for applying changes to the Dockerfiles or configuration files without losing your data.
* `make rebuild-<service>`: Rebuilds the data volume for a specific service (e.g., `make rebuild-wordpress`).

Rules for accessing the database:
* `make db`: Accesses the MariaDB ozamoradb database as the WordPress user (interactive shell).
* `make db-root`: Accesses the MariaDB ozamoradb database as the root user (interactive shell).

Rules for cleaning up the environment:
* `make clean`: Stops and removes the active project containers, networks, and internal Docker-built images.
* `make clean-data`: Removes the persistent data volumes for all services.
* `make clean-docker`: Cleans up Docker resources, including unused images, containers, and
 networks.
* `make fclean`: Triggers a deep cleanup. It executes `make clean`, `make clean-data`, and `make clean-docker`.
* `make re`: Performs a complete rebuild from scratch by executing `make fclean` followed by `make all`.

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
