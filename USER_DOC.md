# User Documentation for Inception project by ozamora-

This file explains, in clear and simple
terms, how an end user or administrator can:
* Understand what services are provided by the stack.
* Start and stop the project.
* Access the website and the administration panel.
* Locate and manage credentials.
* Check that the services are running correctly.

---

## Index
- [Services Overview](#services-overview)
- [Start and Stop the Project](#start-and-stop-the-project)
- [Accessing the Website and Admin Panel](#accessing-the-website-and-admin-panel)
- [Credentials Management](#credentials-management)
- [Service Health Check](#service-health-check)

---

## Services Overview

The project runs **three separate services** (containers) that talk to each other inside a secure, private network:

1. **NGINX (Web Server)**

	- Runs on **Debian Bookworm** and serves as the reverse proxy for the WordPress application on port **443** (Default port for HTTPS).
	- Reverse proxy means that NGINX receives the requests from the client (browser) and forwards them to the appropriate service (WordPress) without exposing the internal structure of the application.
	- Acts as the only entrance to the system from the outside.
	- It is configured to only allow secure connections using strong encryption (**TLSv1.2** and **TLSv1.3**).
	- It serves static files and forwards requests for PHP pages to WordPress.

2. **WordPress (Application Server - PHP-FPM 8.2)**
	- Runs on **Debian Bookworm** and processes the WordPress core files using PHP-FPM on port **9000**.
	- PHP-FPM (FastCGI Process Manager) is a PHP implementation that allows for better performance and scalability by managing multiple PHP processes and handling requests efficiently.
	- It does not contain a web server. It only runs the PHP interpreter and communicates with NGINX and the Database.
	- It is isolated and cannot be accessed from outside the virtual network.
	- It is responsible for generating the dynamic content of the website, such as posts, pages, and user interactions.
	- It communicates with the MariaDB database to store and retrieve data.
	- It is the main interface for users to interact with the website.
	- It is also the interface for administrators to manage the website content and settings through the WordPress admin panel.

3. **MariaDB (Database Server)**
	- Runs on **Debian Bookworm** on port **3306**.
	- Stores all the website data (users, posts, settings) in a safe database.
	- It is isolated and cannot be accessed from outside the virtual network.
	- It is responsible for storing and retrieving data for the WordPress application.
	- It is the backend of the application, providing a structured way to manage data and relationships between different entities (e.g., users, posts, comments).
	- It is configured to allow remote connections from the WordPress container, but not from the outside world, ensuring that only authorized services can access the database.

---

## Start and Stop the Project

You can manage the entire application using the **Makefile** in the root of the project. It automates all the long Docker commands for you.

### 1. To Start the Project for the First Time
This command will create the required folders on your host virtual machine, build the custom Docker images, and start the containers in the background:
```bash
make
```
It is the equivalent of running:
```bash
make build up
```

### 2. To Stop the Project Safely
This stops the running containers without deleting any of your saved data:
```bash
make down
```

### 3. To Clean the Project
This stops the containers and deletes the network and built images, but keeps your files and database intact:
```bash
make clean
```

### 4. To Reset and Wipe Everything (Full Reset)
**Warning: This will delete all your WordPress posts, configurations, and database files.** It wipes out the data folders on your host to let you start completely fresh:
```bash
make fclean
```

### 5. The complete list of Makefile commands
Main rules for managing the project lifecycle:
* `make all` (or `make`): Automatically creates host storage directories for WordPress and MariaDB, builds the custom Docker images, and launches the stack in detached mode.
* `make dirs`: Creates the necessary directories for persistent data storage on the host machine.
* `make build`: Compiles the custom Docker images without launching the containers.
* `make up`: Starts previously compiled services in detached mode (`-d`).
* `make down`: Gracefully stops the containers without deleting persistent volume directories.
* `make start`: Starts the containers without rebuilding them.
* `make stop`: Stops the containers without deleting them.
* `make restart`: Stops and then starts the containers.
* `make status`: Displays the status of the images and running containers.

Rules for displaying logs
* `make logs`: Displays the logs of all containers in real-time.
* `make logs-mariadb`: Displays the logs of the MariaDB container in real-time.
* `make logs-wordpress`: Displays the logs of the WordPress container in real-time.
* `make logs-nginx`: Displays the logs of the NGINX container in real-time.

Rules for rebuilding services preserving persistent data:
* `make rebuild-data`: Rebuilds the data volumes for all services.
* `make rebuild-mariadb`: Rebuilds the MariaDB data volume.
* `make rebuild-wordpress`: Rebuilds the WordPress data volume.
* `make rebuild-nginx`: Rebuilds the NGINX data volume.

Rules for accessing the database and checking the status of services:
* `make db`: Accesses the MariaDB ozamoradb database as the WordPress user (interactive shell).
* `make db-root`: Accesses the MariaDB ozamoradb database as the root user (interactive shell).
* `make db-check`: Displays the list of databases in MariaDB, users and their grants (permissions and privileges). 
* `make wp-check`: Displays the list of users and their roles in WordPress. Also the URL
* `make ls-containers`: Lists the critical directories for each running container.

Rules for cleaning up the environment:
* `make clean`: Stops and removes the active project containers, networks, and internal Docker-built images.
* `make clean-data`: Removes the persistent data volumes for all services.
* `make clean-docker`: Cleans up Docker resources, including unused images, containers, and
 networks.
* `make fclean`: Triggers a deep cleanup. It executes `make clean`, `make clean-data`, and `make clean-docker`.
* `make re`: Performs a complete rebuild from scratch by executing `make fclean` followed by `make all`.
---

## Accessing the Website and Admin Panel

Since this project runs in a secure virtual machine, you need to configure your computer's browser to read the local domain.

### Step 1: Tell your computer where to find the domain
You need to map the domain `ozamora.42.fr` to your local machine.
- **On macOS or Linux:** Open your terminal and run `sudo nano /etc/hosts`. Add this line at the bottom:
  ```text
  127.0.0.1 ozamora.42.fr
  ```
- **On Windows:** Open Notepad as **Administrator**, open `C:\Windows\System32\drivers\etc\hosts`, and add the same line:
  ```text
  127.0.0.1 ozamora.42.fr
  ```

### Step 2: Access the site in your browser
Open your browser and visit:
- **Main Website:** [https://ozamora.42.fr](https://ozamora.42.fr)
- **WordPress Admin Panel:** [https://ozamora.42.fr/wp-admin](https://ozamora.42.fr/wp-admin)

### Step 3: Skip the SSL/Security Warning
Because we are using a self-signed security certificate (which is normal and required for testing), your browser will show a red warning saying the site is unsafe.
- **On Chrome:** Click anywhere on the blank warning screen and type: **`thisisunsafe`** on your keyboard. The page will reload and show the site.
- **On Safari or Firefox:** Click "Advanced" or "Show Details" and choose "Proceed to website" or "Accept the risk".

---

## Credentials Management

Your configuration settings and secret passwords are kept separate to ensure safety.

### 1. General Configuration (`srcs/.env`)
The file `srcs/.env` contains general variables such as the domain name, database names, and admin emails.
- **Example:** `DOMAIN_NAME=ozamora.42.fr`

### 2. Private Passwords (`secrets/` directory)
Sensitive passwords are saved in small text files inside the `secrets/` directory in the root of the project:
- `secrets/db_password.txt`: Password for the WordPress database user.
- `secrets/db_root_password.txt`: Master password for the MariaDB database root administrator.

> 🔒 **Security Notice:** Both the `srcs/.env` file and the `secrets/` folder are listed in `.gitignore`. They will **never** be uploaded to GitHub, which is a strict rule to pass the project.

---

## Service Health Check

If the website does not load, you can check if the services are healthy using these quick terminal commands inside your Virtual Machine:

### 1. Check if the containers are running
```bash
docker ps
```
- You should see three containers listed: `nginx`, `wordpress`, and `mariadb`.
- Their status should say **`Up`** (not `Restarting` or `Exited`).

### 2. Read the log files to spot errors
If a service is down, read its logs to find out why:
```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### 3. Inspect the virtual network
To verify that all three containers are connected to the same isolated network:
```bash
docker network inspect inception_network
```

### 4. Check the Database status
You can enter the database directly via the command line to verify that your data is safe:
```bash
docker exec -it mariadb mysql -u root -p
```
*(Enter your root password from `secrets/db_root_password.txt` when prompted)*. Once inside, you can run SQL commands like `SHOW DATABASES;` to check the status.
