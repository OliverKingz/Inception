*This project has been created as part of the 42 curriculum by ozamora-.*

# Inception

[42 Madrid] Inception is a system administration project at school 42. The main goal is to design a small, completely containerized, secure, and multi-service infrastructure using **Docker** and **Docker Compose** inside a Virtual Machine, with each image built from scratch using custom Dockerfiles.

---

## Index
- [Description](#description)
- [Instructions](#instructions)
	- [Initial Setup](#initial-setup)
	- [Building and Running](#building-and-running)
	- [Cleanup and Diagnostics](#cleanup-and-diagnostics)
- [Project Description](#project-description)
	- [Technical Choices and Design](#technical-choices-and-design)
	- [Architecture Comparison Matrix](#architecture-comparison-matrix)
- [Resources and AI Usage](#resources-and-ai-usage)

---

## Description
This project focuses on deploying a classic **LEMP stack** (Linux, NGINX, MariaDB, PHP-FPM) running inside a private Docker bridge network. The architecture is split into three independent, dedicated microservices:
1.  **NGINX:** Acts as the reverse proxy and secure entry point, handling TLS/HTTPS on port `443` and serving static content. Uses a self-signed SSL certificate generated with OpenSSL.
2.  **WordPress:** Hosts the PHP-FPM 8.2 runtime to process WordPress application logic. It communicates with NGINX via port `9000`.
3.  **MariaDB:** Serves as the relational database engine, storing posts, comments, and user credentials. It communicates with WordPress via port `3306`.

It also includes:
* Two persistent Docker named volumes for storing the database and WordPress files, ensuring that data is preserved across container rebuilds.
* One dedicated Docker network connecting all services. 

---

## Instructions

### Initial Setup
To simulate a real web server environment, the domain must be mapped to your local loopback address:
1.  Open the `/etc/hosts` file on your VM Host:
    ```bash
    sudo nano /etc/hosts
    ```
2.  Add the following line mapping your domain to localhost:
    ```text
    127.0.0.1   ozamora-.42.fr
    ```
3.  Create the credentials file `srcs/.env` and the secure secrets folder (`secrets/`) at the root of the project containing:
    *   `secrets/MYSQL_PASSWORD.txt`
    *   `secrets/MYSQL_ROOT_PASSWORD.txt`
	*   `secrets/WORDPRESS_PASS.txt`
	*   `secrets/WORDPRESS_ROOT_PASS.txt`

You can use the provided `srcs/.env.example` as a template for the `.env` file.

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

To create the necessary secrets, you can use the following commands:
```bash
echo "password" > secrets/MYSQL_PASSWORD.txt
echo "password" > secrets/MYSQL_ROOT_PASSWORD.txt
echo "password" > secrets/WORDPRESS_PASS.txt
echo "password" > secrets/WORDPRESS_ROOT_PASS.txt
```

### Building and Running
The compilation and startup are automated via the root-level `Makefile`:
*   **Compile and Start the Stack:**
    ```bash
    make
    ```
    This command automatically ensures the local storage folders exist, compiles the Dockerfiles, and runs the containers.
*   **Stop the Stack:**
    ```bash
    make down
    ```

### Cleanup and Diagnostics
*   **Reset the Environment (Preserves Data):**
    ```bash
    make clean
    ```
*   **Purge the Environment (Deletes Persistent Volumes):**
    ```bash
    make fclean
    ```
*   **Check Services Status:**
    ```bash
    docker ps
    ```
*   **Access the Site:**
    Open your physical browser and go to `https://ozamora-.42.fr`. Since the SSL certificate is self-signed, bypass the warning. 

---

## Project Description
Docker is used to create isolated containers for each service, allowing them to run independently while sharing the same host kernel. Using Docker Compose, we define the services, networks, and volumes in a single `docker-compose.yml` file, enabling easy orchestration of the multi-container application.

```bash
├── DEV_DOC.md
├── USER_DOC.md
├── README.md
├── Makefile
├── secrets
│   ├── MYSQL_PASSWORD.txt
│   ├── MYSQL_ROOT_PASSWORD.txt
│   ├── WORDPRESS_ADMIN_PASSWORD.txt
│   └── WORDPRESS_PASSWORD.txt
├── srcs
    ├── docker-compose.yml
    └── requirements
        ├── mariadb
        │   ├── conf
        │   │   └── 50-server.cnf
        │   ├── Dockerfile
        │   └── tools
        │       └── init_db.sh
        ├── nginx
        │   ├── conf
        │   │   └── nginx.conf
        │   ├── Dockerfile
        │   └── tools
        │       └── generate_ssl.sh
        └── wordpress
            ├── conf
            │   └── www.conf
            ├── Dockerfile
            └── tools
                └── setup_wordpress.sh
```

### Technical Choices and Design
*   **SSL Certificate Generation:** OpenSSL is used to generate a self-signed certificate for HTTPS. The NGINX configuration enforces TLS v1.2 and v1.3 protocols, ensuring secure communication.
It was chosen to be added at the entry point script of the NGINX container to ensure that the certificate is generated at runtime and not stored in the repository.
Other options of storing the certificate and why they were not chosen, even if they save time:
	*   **Storing in a Volume (/data):** Not chosen due to the subject, as it ask for only two volumes
	*   **Storing in a Docker Secret:** Not chosen because the certificate is not a secret, and it is not sensitive information. It is public information that can be shared with anyone.
	*   **Storing in the Container Image:** Not chosen because it would require rebuilding the image every time the certificate is updated, which is not efficient.
*   **Debian Base Image:** Every service is built from scratch starting with `debian:bookworm` (Debian 12). It was chosen over Alpine Linux due to its better compatibility with the latest versions of NGINX, MariaDB, and PHP-FPM, as well as its more extensive package repository.
*   **Safe Database Bootstrapping:** In our custom MariaDB script, we utilize an isolated temporal-start loop to create users and assign secure credentials before running the definitive PID 1 daemon.
*   **Security Best Practices:** The project adheres to security best practices by using Docker secrets for passwords, enforcing TLS protocols, and isolating services within a private network.
*   **WP-CLI Usage:** The WordPress Command Line Interface (WP-CLI) is used to automate the initial setup of the WordPress site, including creating the admin user and configuring the database connection.

### Architecture Comparison Matrix

#### 1. Virtual Machines vs Docker

| Feature | Virtual Machine | Docker |
| :--- | :--- | :--- |
| **Isolation** | Full guest OS | Isolated process |
| **Kernel** | Own virtual kernel | Shares host kernel |
| **Size** | Gigabytes (GB) | Megabytes (MB) |
| **Startup** | Minutes | Seconds |
| **Overhead** | Heavy (hypervisor) | Lightweight (near-native) |

* **VM:** Emulates an entire computer with its own complete operating system.
* **Docker:** Runs isolated processes directly on the host kernel. Much lighter and faster.

#### 2. Docker Secrets vs Environment Variables

| Feature | Docker Secrets | Environment Variables |
| :--- | :--- | :--- |
| **Location** | File in RAM (`/run/secrets/`) | Process memory space |
| **Visibility** | Hidden, container-only | Plain text via `docker inspect` |
| **Security** | High | Low for sensitive data |
| **Inception Usage** | Passwords, private keys, tokens | Domain names, public users, ports |

* **Environment Variables:** For public settings. Stored in plain text and easily exposed in logs or CLI inspections.
* **Docker Secrets:** For sensitive credentials. Mounted as in-memory files only accessible to the authorized container.

#### 3. Docker Network (Bridge) vs Host Network

| Feature | Docker Network (Bridge) | Host Network |
| :--- | :--- | :--- |
| **Isolation** | Private internal network | Direct host network interface |
| **DNS / Routing** | By service name (`mariadb`) | By `localhost` only |
| **Security** | High (ports private by default) | None (ports exposed to host directly) |
| **Inception Rule** | Mandatory custom bridge | Strictly forbidden (`--network=host`) |

* **Docker Network:** An isolated virtual network where containers communicate safely by name without exposing internal ports.
* **Host Network:** Removes all isolation, sharing the host stack directly and exposing internal services to outside traffic.

#### 4. Docker Volumes vs Bind Mounts

| Feature | Docker Volumes | Bind Mounts |
| :--- | :--- | :--- |
| **Management** | Fully managed by Docker | Managed manually by the user |
| **Default Path** | `/var/lib/docker/volumes/` | Any host path (`/home/ozamora-/data/`) |
| **Deletion** | Removed with `docker volume rm` | Never deleted by Docker commands |
| **Inception Usage** | Named volumes backed by local storage | Strict requirement to store data in `/home` |

* **Docker Volumes:** Docker manages the storage location and lifecycle inside its own system directory.
* **Bind Mounts:** You link an exact physical directory from your machine, ensuring data survives even complete Docker purges.

---

## Resources and AI Usage

### Classic References
*   [Debian Release Notes](https://www.debian.org/releases/)
*   [Docker Documentation](https://docs.docker.com/)
*   [Docker Compose Documentation](https://docs.docker.com/compose/)
*   [WordPress Command Line Interface (WP-CLI) Handbook](https://make.wordpress.org/cli/handbook/)
*   [NGINX Documentation & TLS Configuration Guides](https://nginx.org/en/docs/)
*   [MariaDB Documentation](https://mariadb.com/docs/)

### AI Usage Disclosure
In accordance with 42 guidelines, AI tools (Gemini Notebook, Docker AI) were used as technical tutors and productivity assistants for:
* **Command Syntax & Mechanics:** Understanding complex CLI commands, flags, parameter expansions, and the underlying reasoning behind configurations.
* **Core Concepts:** Clarifying low-level mechanisms such as PID 1 signal forwarding, Docker networking, and TLS v1.2/v1.3 protocols VS legacy SSL.
* **Script Debugging:** Troubleshooting initialization scripts, container restart loops.
* **Documentation & Makefile:** Structuring guides and refining automation rules.
* **Best Practices:** Ensuring security, maintainability, and adherence to modern standards in Docker and Linux administration.


*All generated recommendations were reviewed, understood, and manually implemented.*