_This project has been created as part of the 42 curriculum by ozamora-._

# Developer Documentation | Inception

This file explains, in clear and simple terms, how a developer can:

- Set up the environment from scratch (prerequisites, configuration files, secrets).
- Build and launch the project using the Makefile and Docker Compose.
- Use relevant commands to manage the containers and volumes.
- Identify where the project data is stored and how it persists.

---

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
   - [Prerequisites](#prerequisites)
   - [Domain Name Configuration](#domain-name-configuration)
   - [Environment Variables and Secrets](#environment-variables-and-secrets)
2. [Project Architecture & Directory Structure](#project-architecture--directory-structure)
   - [Directory Layout](#directory-layout)
   - [Service Communication Flow](#service-communication-flow)
3. [Build & Launch Workflows](#build--launch-workflows)
   - [First-Time Deployment](#first-time-deployment)
   - [Makefile Commands](#makefile-commands)
   - [Docker Compose Integration](#docker-compose-integration)
4. [Data Storage & Persistence Architecture](#data-storage--persistence-architecture)
   - [Bind Mounts Configuration](#bind-mounts-configuration)
   - [Verifying Data Persistence](#verifying-data-persistence)
5. [Container Management & Debugging Workflows](#container-management--debugging-workflows)
   - [Service Health & Logs Inspection](#service-health--logs-inspection)
   - [Database Inspection Commands](#database-inspection-commands)
   - [Rebuilding Individual Services](#rebuilding-individual-services)
6. [Technical & Architectural Choices](#technical--architectural-choices)

---

## Development Environment Setup

### Prerequisites

Before building or running the stack, ensure the host machine (Debian Virtual Machine) has the following software installed:

- **Operating System:** Linux-based distribution with a kernel version that supports Docker.
- **Docker Engine:** installed and running.
- **Docker Compose:** using the modern `docker compose` plugin syntax, not the deprecated standalone `docker-compose`.
- **GNU Make:** installed to utilize the provided Makefile for automation.
- **Git:** installed to clone the repository.

To verify prerequisite installation:

```bash
docker --version
docker compose version
make --version
git --version
```

### Domain Name Configuration

The project requirement specifies mapping the local domain `ozamora.42.fr` to the local loopback address (`127.0.0.1`).

Add the domain mapping to `/etc/hosts` on your development host / VM:

```bash
echo "127.0.0.1 ozamora.42.fr" | sudo tee -a /etc/hosts
```

Verify resolution:

```bash
ping -c 3 ozamora.42.fr
```

### Environment Variables

Public and general configuration variables are stored in `srcs/.env`. This file is loaded by `docker-compose.yml` and must **never** be committed to Git.

You can use the provided `srcs/.env.example` as a template to create the `.env` file.

```bash
# Environment variables for Inception project
DOMAIN_NAME=ozamora-.42.fr

# Database configuration (MySQL / MariaDB)
MYSQL_HOSTNAME=mariadb
MYSQL_DATABASE=ozamoradb
MYSQL_USER=ozamora
MYSQL_PASSWORD=
MYSQL_ROOT_USER=root
MYSQL_ROOT_PASSWORD=

# Wordpress configuration
WORDPRESS_TITLE=Inception

WORDPRESS_USER=ozamora
WORDPRESS_EMAIL=author@ozamora-.42.fr
WORDPRESS_PASSWORD=

WORDPRESS_ADMIM=ozamora_master
WORDPRESS_ADMIM_EMAIL=master@ozamora-.42.fr
WORDPRESS_ADMIN_PASSWORD=

# Secret files (inside containers, at /run/secrets)
MYSQL_PASSWORD_FILE=/run/secrets/MYSQL_PASSWORD
MYSQL_ROOT_PASSWORD_FILE=/run/secrets/MYSQL_ROOT_PASSWORD

WORDPRESS_ADMIN_PASSWORD_FILE=/run/secrets/WORDPRESS_ADMIN_PASSWORD
WORDPPRESS_PASSWORD_FILE=/run/secrets/WORDPRESS_PASSWORD
```

### Docker Secrets Setup

Sensitive credentials (passwords) are strictly managed via **Docker Secrets** to prevent exposure in environment variables or `docker inspect` outputs.

Create the the secure secrets folder (`secrets/`) at the root of the project containing:
_ `secrets/MYSQL_PASSWORD.txt`
_ `secrets/MYSQL_ROOT_PASSWORD.txt`
_ `secrets/WORDPRESS_ADMIN_PASSWORD.txt`
_ `secrets/WORDPRESS_PASSWORD.txt`

To create the necessary secrets, you can use the following commands:

```bash
mkdir -p secrets

# Change the following passwords to your desired secure values
echo "password" > secrets/MYSQL_PASSWORD.txt
echo "password" > secrets/MYSQL_ROOT_PASSWORD.txt
echo "password" > secrets/WORDPRESS_PASS.txt
echo "password" > secrets/WORDPRESS_ROOT_PASS.txt

# Secure permissions (read-only for owner)
chmod 600 secrets/*.txt
```

Verify that `.gitignore` contains:

```gitignore
.env
srcs/.env
secrets/
```

---

## Project Architecture & Directory Structure

### Directory Layout

The repository follows the mandatory 42 Inception layout structure:

```text
Inception/
├── Makefile                        ← Top-level automation entrypoint
├── README.md                       ← Project overview and usage instructions
├── USER_DOC.md                     ← User documentation
├── DEV_DOC.md                      ← Developer documentation
├── secrets/                        ← Sensitive password files (ignored by Git)
│   ├── MYSQL_PASSWORD.txt             ← WordPress DB user password
│   ├── MYSQL_ROOT_PASSWORD.txt        ← MariaDB root password
│   ├── WORDPRESS_PASSWORD.txt         ← WordPress user password
│   └── WORDPRESS_ADMIN_PASSWORD.txt   ← WordPress admin password
└── srcs/
	├── .env                        ← Environment variables (ignored by Git)
	├── docker-compose.yml          ← Multi-container orchestration specification
	└── requirements/
		├── mariadb/
		│   ├── Dockerfile          ← Debian Bookworm + MariaDB Server
		│   ├── conf/
		│   │   └── 50-server.cnf   ← Network & socket configuration
		│   └── tools/
		│       └── init_db.sh      ← Initialization & privilege setup script
		├── nginx/
		│   ├── Dockerfile          ← Debian Bookworm + NGINX
		│   ├── conf/
		│   │   └── nginx.conf      ← TLS 1.2/1.3 reverse proxy configuration
		│   └── tools/
		│       └── generate_ssl.sh ← Dynamic SSL certificate generation script
		└── wordpress/
			├── Dockerfile          ← Debian Bookworm + PHP 8.2-FPM
			├── conf/
			│   └── www.conf        ← PHP-FPM FastCGI pool configuration
			└── tools/
				└── setup_wordpress.sh ← WP-CLI installation entrypoint
```

### Service Communication Flow

All services run in dedicated, isolated containers connected via an explicit private bridge network (`inception_network`):

```text
[ Browser / Host ]
	   │
   HTTPS:443
	   ▼
 ┌───────────┐
 │   NGINX   │  (Listens on 443, terminates TLS v1.2/v1.3, serves static files)
 └─────┬─────┘
	   │
 FastCGI:9000 (Internal Docker Network)
	   ▼
 ┌───────────┐
 │ WordPress │  (Runs PHP-FPM 8.2 on port 9000, executes application logic)
 └─────┬─────┘
	   │
   MySQL:3306 (Internal Docker Network)
	   ▼
 ┌───────────┐
 │  MariaDB  │  (Listens on port 3306, stores persistent database tables)
 └───────────┘
```

---

## Build & Launch Workflows

### First-Time Deployment

To initialize directories, compile custom images, and launch all services in detached mode:

```bash
cd ~/Inception
make
```

The `make` command automatically uses the rules `dirs`, `env`, `build`, and `up` in sequence:

1. Creates host volume directories (`/home/ozamora-/data/mariadb` & `/home/ozamora-/data/wordpress`) if they do not exist.
2. Checks for the presence of the environment variables in `srcs/.env`, and copies them from `srcs/.env.example` if missing.
3. Invokes `docker compose -f srcs/docker-compose.yml build` to build Debian Bookworm images for NGINX, WordPress, and MariaDB with custom configurations.
4. Spawns containers on `inception_network` in detached mode (`up -d`).
5. Waits for the WordPress and PHP-FPM services to be ready to accept connections.

### Makefile Commands

The root `Makefile` provides standardized control targets:

| Command                  | Description                                                                                            |
| :----------------------- | :----------------------------------------------------------------------------------------------------- |
| `make` / `make all`      | Executes the `dirs`, `env`, `build`, and `up` rules in sequence.                                       |
| `make dirs`              | Creates the necessary directories for persistent data.                                                 |
| `make env`               | Creates the `.env` file with default environment variables if it doesn't exist.                        |
| `make build`             | Builds the custom Docker images without launching containers.                                          |
| `make up`                | Starts previously built services in detached mode. Waits for readiness                                 |
| `make down`              | Stops and removes containers without deleting persistent volume directories.                           |
| `make start`             | Starts the containers without rebuilding them.                                                         |
| `make stop`              | Stops the containers without deleting them.                                                            |
| `make restart`           | Stops and then starts the containers.                                                                  |
| `make images`            | Lists the Docker images that have been built for the project.                                          |
| `make ps`                | Lists the running containers and their status.                                                         |
| `make status`            | Displays the status of the images and running containers.                                              |
| `make logs`              | Displays the logs of all containers in real-time.                                                      |
| `make logs-<service>`    | Displays the logs of a specific service (e.g., `make logs-wordpress`).                                 |
| `make db-check`          | Displays the list of databases in MariaDB, users and their grants (permissions and privileges).        |
| `make wp-check`          | Displays the list of users and their roles in WordPress. Also the URL.                                 |
| `make nginx-check`       | Checks the syntax of the NGINX configuration files and reports any errors or warnings.                 |
| `make network-check`     | Inspects the Docker network created by docker-compose to ensure all containers are connected properly. |
| `make ls-containers`     | Lists the critical directories for each running container.                                             |
| `make rebuild-all`       | Rebuilds all the services, useful for applying changes to the Dockerfiles/configuration files.         |
| `make rebuild-<service>` | Rebuilds the data volume for a specific service                                                        |
| `make db`                | Accesses the MariaDB ozamoradb database as the WordPress user (interactive shell).                     |
| `make db-root`           | Accesses the MariaDB ozamoradb database as the root user (interactive shell).                          |
| `make clean`             | It executes `make down`. In addition, it removes dangling containers.                                  |
| `make clean-data`        | Removes the persistent data volumes for all services.                                                  |
| `make clean-docker`      | Cleans up Docker resources, including all dangling Docker images, volumes and residual cache.          |
| `make fclean`            | Triggers a deep cleanup. It executes `make clean`, `make clean-data`, and `make clean-docker`.         |
| `make re`                | Performs a complete rebuild from scratch by executing `make fclean` followed by `make all`.            |

### Docker Compose Integration

The orchestration specification in `srcs/docker-compose.yml` ensures:

- **Custom Builds:** Each service builds from its local `requirements/<service>/Dockerfile`. Each service has its own build context and Dockerfile, allowing for modular and maintainable image builds.
- **Isolated Port Exposure:** Only NGINX publishes host port `443:443`. MariaDB (`3306`) and WordPress (`9000`) use `expose` to remain strictly internal.
- **Restart Policy:** Configured with `restart: always` to automatically restart containers on failure or host reboot.
- **Shared Volumes:** NGINX and WordPress share the `/var/www/html` volume for static file serving, while MariaDB has its own persistent volume for database storage.
- **Dependencies:** Service dependencies are defined using `depends_on` to ensure proper startup order, but health checks are used to verify readiness.
- **Environment Variables:** Loaded from the `.env` file for consistent configuration across services, using `env_file` in the Compose specification.
- **Network Isolation:** All services are connected to a dedicated bridge network (`inception_network`) for secure inter-service communication. `driver: bridge` is used to create an isolated network for the stack.
- **Volume Mounts:** Persistent data is stored in host bind mounts to ensure data survives container recreation.
- **Secret Mounting:** Mounts password files into /run/secrets/ inside the containers using Docker Compose file-based secrets, using `secrets:` and `secret:` directives.

---

## Data Storage & Persistence Architecture

### Bind Mounts Configuration

To satisfy project requirements, persistent data is stored in host bind mounts located in `/home/ozamora-/data/`:

- **Database Persistence:** Mapped from `/var/lib/mysql` inside `mariadb` to `/home/ozamora-/data/mariadb` on the host.
- **WordPress Files:** Mapped from `/var/www/html` inside `wordpress` (and shared with `nginx`) to `/home/ozamora-/data/wordpress` on the host.

Compose specification snippet:

```yaml
volumes:
  mariadb_data:
	driver: local
	driver_opts:
	  type: "none"
	  o: "bind"
	  device: "/home/ozamora-/data/mariadb"
  wordpress_data:
	driver: local
	driver_opts:
	  type: "none"
	  o: "bind"
	  device: "/home/ozamora-/data/wordpress"
```

- `driver: local` means the volume is managed by the local Docker engine.
- `driver_opts` with `type: "none"` means the volume is a bind mount, not a Docker-managed volume.
- `driver_opts` with `o: "bind"` specifies that the volume is a bind mount to a specific host directory. Both are required for bind mounts.
- `driver_opts` with `device` specifies the absolute path on the host where the data will be stored.

### Verifying Data Persistence

To test that data survives container destruction:

1. Access `https://ozamora-.42.fr` and publish a new blog post.
2. Destroy all active containers and networks:
   ```bash
   make down
   ```
3. Relaunch the stack:
   ```bash
   make up
   ```
4. Refresh `https://ozamora-.42.fr`. The blog post and database configuration remain intact.
5. Inspect host physical storage:
   ```bash
   ls -la /home/ozamora-/data/wordpress
   ls -la /home/ozamora-/data/mariadb
   ```

---

## Container Management & Debugging Workflows

### Service Health & Logs Inspection

Check container health and view output logs:

```bash
# View active container status
docker ps

# Inspect logs for specific services
docker logs nginx
docker logs wordpress
docker logs mariadb

# Follow aggregated live logs
docker compose -f srcs/docker-compose.yml logs -f

# Or use the Makefile shortcuts:
make status
make logs
make logs-nginx
make logs-wordpress
make logs-mariadb
```

### Database Inspection Commands

To verify database users and privilege tables directly inside the running MariaDB container:

```bash
# Open interactive MySQL shell using mounted root secret
docker exec -it mariadb mysql -u root -p$(cat /run/secrets/MYSQL_ROOT_PASSWORD) ozamoradb

# Or use the makefiles shortcut:
make db-root
```

SQL verification queries:

```sql
SHOW DATABASES;
USE ozamoradb;
SHOW TABLES;
SELECT ID, user_login, user_email FROM wp_users;
SELECT host, user FROM mysql.user;
```

_(Verify that no administrator account contains the forbidden string `admin` or `Admin`)._

### Rebuilding Individual Services

If you modify configuration files or Dockerfiles for a specific service:

```bash
# Rebuild and restart only NGINX
docker compose -f srcs/docker-compose.yml up -d --build nginx

# Rebuild and restart WordPress
docker compose -f srcs/docker-compose.yml up -d --build wordpress

# Rebuild and restart MariaDB
docker compose -f srcs/docker-compose.yml up -d --build mariadb

# Or use the Makefile shortcuts):
make rebuild-nginx
make rebuild-wordpress
make rebuild-mariadb
make rebuild-all
```

---

## Technical & Architectural Choices

- **SSL Certificate Generation:** OpenSSL is used to generate a self-signed certificate for HTTPS. The NGINX configuration enforces TLS v1.2 and v1.3 protocols, ensuring secure communication.
  It was chosen to be added at the entry point script of the NGINX container to ensure that the certificate is generated at runtime and not stored in the repository.
  Other options of storing the certificate and why they were not chosen, even if they save time:
  - **Storing in a Volume (/data):** Not chosen due to the subject, as it ask for only two volumes
  - **Storing in a Docker Secret:** Not chosen because the certificate is not a secret, and it is not sensitive information. It is public information that can be shared with anyone.
  - **Storing in the Container Image:** Not chosen because it would require rebuilding the image every time the certificate is updated, which is not efficient.
- **Debian Base Image:** Every service is built from scratch starting with `debian:bookworm` (Debian 12). It was chosen over Alpine Linux due to its better compatibility with the latest versions of NGINX, MariaDB, and PHP-FPM, as well as its more extensive package repository.
- **Safe Database Bootstrapping:** In our custom MariaDB script, we utilize an isolated temporal-start loop to create users and assign secure credentials before running the definitive PID 1 daemon.
- **Security Best Practices:** The project adheres to security best practices by using Docker secrets for passwords, enforcing TLS protocols, and isolating services within a private network.
- **WP-CLI Usage:** The WordPress Command Line Interface (WP-CLI) is used to automate the initial setup of the WordPress site, including creating the admin user and configuring the database connection.
- **Docker Secrets over Environment Variables:** Keeps passwords out of container environment variables and makes them available as files under `/run/secrets/`. The current Compose configuration uses file-based secrets.
- **PID 1 Signal Handling:** Service entrypoint scripts use `exec` to replace the shell process with the main service daemon as PID 1, ensuring clean signal forwarding (`SIGTERM`) without resorting to forbidden loops (`tail -f`, `sleep infinity`). The scripts are used as ENTRYPOINT at the Dockerfile level, not as CMD, to ensure that the service is the main process and receives signals directly from Docker. The daemon remplaza the shell process, remaining as PID 1.
  All three are PID 1 processes in their respective containers, allowing Docker to control their lifecycle and handle signals properly.
  All three services use the following commands to start their respective daemons at the end of their entrypoint scripts:
  - `exec mysqld` for MariaDB. Already runs as PID 1, so no additional flags are needed.
  - `exec php-fpm8.2 -F` for WordPress (PHP-FPM). -F flag is specific for PHP-FPM to run in the foreground.
  - `exec nginx -g "daemon off;"` for NGINX. -g flag is used to pass global directives to NGINX, and "daemon off;" tells NGINX to run in the foreground.
