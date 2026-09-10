# **************************************************************************** #
# VARIABLES

NAME          = Inception
COMPOSE_FILE  = srcs/docker-compose.yml
DATA_DIR      = /home/$(USER)/data
DOMAIN_NAME    = $(shell grep DOMAIN_NAME srcs/.env | cut -d '=' -f2)

CYAN          = \033[0;36m
GREEN         = \033[0;32m
YELLOW        = \033[0;33m
RED           = \033[0;31m
RESET         = \033[0m

define ASCII_ART

──────────────────────────────────────────────────────────────
                                                       
        ▄▄▄▄▄▄                                          
       █▀ ██                           █▄               
          ██   ▄                      ▄██▄▀▀       ▄    
          ██   ████▄ ▄███▀ ▄█▀█▄ ████▄ ██ ██ ▄███▄ ████▄
          ██   ██ ██ ██    ██▄█▀ ██ ██ ██ ██ ██ ██ ██ ██
        ▄▄██▄▄▄██ ▀█▄▀███▄▄▀█▄▄▄▄████▀▄██▄██▄▀███▀▄██ ▀█
                                 ██                     
                                 ▀            by ozamora- 
──────────────────────────────────────────────────────────────

endef
export ASCII_ART

# **************************************************************************** #
# RULES

all: build up

$(DATA_DIR)/mariadb:
	@echo "$(YELLOW)Creating directory for MariaDB in $(DATA_DIR)/mariadb$(RESET)"
	@mkdir -p $(DATA_DIR)/mariadb

$(DATA_DIR)/wordpress:
	@echo "$(YELLOW)Creating directory for WordPress in $(DATA_DIR)/wordpress$(RESET)"
	@mkdir -p $(DATA_DIR)/wordpress

help:
	@echo "$(CYAN)Available commands:$(RESET)"
	@echo "  make all               - Build and start the entire infrastructure"
	@echo "  make env               - Create .env file with default environment variables if it doesn't exist"
	@echo "  make dirs              - Create necessary directories for persistent data"
	@echo "  make build             - Build Docker images"
	@echo "  make up                - Start containers in the background"
	@echo "  make down              - Stop and remove containers. Keeps images and volumes"
	@echo "  make start             - Start containers without removing them"
	@echo "  make stop              - Stop containers without removing them"
	@echo "  make restart           - Restart containers without rebuilding them"
	@echo "  make images            - Display status of Docker images"
	@echo "  make ps                - Display status of running containers"
	@echo "  make status            - Display status of images and containers"
	@echo "  make logs              - Display logs of all containers"
	@echo "  make db-check          - Check databases, users, and grants in MariaDB"
	@echo "  make wp-check          - Check WordPress users and site URL"
	@echo "  make nginx-check       - Check NGINX configuration syntax"
	@echo "  make network-check     - Inspect the Docker network created by docker-compose"
	@echo "  make ls-containers     - List critical directories inside running containers"
	@echo "  make logs-[service]    - Display logs of a specific container (e.g., logs-mariadb)"
	@echo "  make rebuild-all       - Rebuild all services preserving data"
	@echo "  make rebuild-[service] - Rebuild a specific service preserving data (e.g., rebuild-wordpress)"
	@echo "  make db                - Access MariaDB as wpuser (interactive shell)"
	@echo "  make db-root           - Access MariaDB as root (interactive shell)"
	@echo "  make clean             - Stop and remove containers. Keeps images and volumes."
	@echo "  make clean-data        - Remove persistent data directories for MariaDB and WordPress"
	@echo "  make clean-docker      - Remove dangling Docker images and residual cache"
	@echo "  make fclean            - Fully clean the system (containers, images, volumes, data, docker)"
	@echo "  make re                - Fully clean and rebuild the entire infrastructure"

dirs: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@echo "$(GREEN)All necessary directories are ready!$(RESET)"

env:
	@if [ ! -f srcs/.env ]; then \
		@echo "$(YELLOW)Creating .env file with default environment variables$(RESET)"; \
		@cp srcs/.env.example srcs/.env; \
	fi

build: dirs env
	@echo "$(GREEN)Docker build: compiling images in docker$(RESET)"
	docker compose -f $(COMPOSE_FILE) build

up:
	@echo "$(GREEN)Docker up: creating and starting containers in the background$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(YELLOW) Waiting for WordPress and PHP-FPM to be ready$(RESET)"
	@until docker exec wordpress wp core is-installed --allow-root --path=/var/www/html >/dev/null 2>&1; do \
		sleep 2; \
	done
	@printf "$$ASCII_ART\n"
	@echo "$(GREEN)Infrastructure is now active! Access at https://$(DOMAIN_NAME)$(RESET)"

down:
	@echo "$(YELLOW)Docker down: stopping and removing containers. Keeps images and volumes.$(RESET)"
	docker compose -f $(COMPOSE_FILE) down

start:
	@echo "$(GREEN)Docker start: starting containers without removing them$(RESET)"
	docker compose -f $(COMPOSE_FILE) start

stop:
	@echo "$(YELLOW)Docker stop: stopping containers without removing them$(RESET)"
	docker compose -f $(COMPOSE_FILE) stop

restart:
	@echo "$(YELLOW)Docker restart: restarting (stop+start) containers without rebuilding them$(RESET)"
	docker compose -f $(COMPOSE_FILE) restart

# **************************************************************************** #
# Rules for displaying information and logs

images:
	@echo "$(YELLOW)Displaying status of images$(RESET)"
	docker images

ps:
	@echo "$(YELLOW)Displaying status of containers$(RESET)"
	docker ps

status: images ps

logs:
	@echo "$(YELLOW)Displaying logs of containers$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f

logs-%:
	@echo "$(YELLOW)Displaying logs of $*$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f $*

# **************************************************************************** #
# Rules for checking the health of the services, database, network and containers

db-check:
	@echo "$(CYAN)[$(NAME)] Databases:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u "$$MYSQL_USER" -p"$$(cat /run/secrets/MYSQL_PASSWORD)" -e "SHOW DATABASES;"'
	@echo "\n$(CYAN)[$(NAME)] Users:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" -e "SELECT User, Host FROM mysql.user;"'
	@echo "\n$(CYAN)[$(NAME)] Grants:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" -e "SHOW GRANTS FOR '\''ozamora'\''@'\''%'\'';"'
	@echo "\n$(CYAN)[$(NAME)] Grants for root:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" -e "SHOW GRANTS FOR '\''root'\''@'\''localhost'\'';"'

wp-check:
	@echo "\n$(CYAN)[WordPress] Users list and roles:$(RESET)"
	docker exec wordpress wp user list --allow-root --path=/var/www/html
	@echo "\n$(CYAN)[WordPress] URLs that are configured in the DB:$(RESET)"
	docker exec wordpress wp option get siteurl --allow-root --path=/var/www/html

nginx-check:
	@echo "\n$(CYAN)[NGINX] Checking NGINX configuration syntax:$(RESET)"
	docker exec -it nginx nginx -t

network-check:
	@echo "\n$(CYAN)[Docker Network] Inspecting the network created by docker-compose:$(RESET)"
	docker network inspect inception_network

ls-containers:
	@echo "$(CYAN)[MariaDB] Critical Directories (/var/lib/mysql, /run/mysqld)$(RESET)"
	docker exec mariadb ls -ld /var/lib/mysql /run/mysqld 2>/dev/null || echo "MariaDB is not running."
	@echo "\n$(CYAN)[WordPress] Root Directory (/var/www/html)$(RESET)"
	docker exec wordpress ls -ld /var/www/html 2>/dev/null || echo "WordPress is not running."
	@echo "\n$(CYAN)[NGINX] Certificates (/etc/nginx/ssl) and Root Directory (/var/www/html)$(RESET)"
	docker exec nginx ls -la /etc/nginx/ssl 2>/dev/null || echo "NGINX is not running."
	docker exec nginx ls -ld /var/www/html 2>/dev/null || true

# **************************************************************************** #
# Rules for rebuilding services preserving persistent data
# Useful for reapplying changes in Dockerfiles or configuration files without losing data

rebuild-all:
	@echo "$(YELLOW)Rebuilding all services$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build mariadb wordpress nginx

rebuild-%:
	@echo "$(YELLOW)Rebuilding $* service$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build $*

# **************************************************************************** #
# Rules for accessing MariaDB

db:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as wpuser (interactive shell)$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u "$$MYSQL_USER" -p"$$(cat /run/secrets/MYSQL_PASSWORD)" $$MYSQL_DATABASE'

db-root:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as root (interactive shell)$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u root -p"$$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" $$MYSQL_DATABASE'

# **************************************************************************** #
# Rules for cleaning up containers, images, and data

clean: down
	@echo "$(YELLOW)Removing all dangling containers$(RESET)"
	docker container prune -f

clean-data:
	@echo "$(RED)Removing data directories in $(DATA_DIR)$(RESET)"
	@if [ -n "$(DATA_DIR)" ] && [ -d "$(DATA_DIR)" ]; then \
		sudo rm -rf $(DATA_DIR)/mariadb/* $(DATA_DIR)/wordpress/* 2>/dev/null || true; \
	fi

clean-docker:
	@echo "$(RED)Removing all dangling Docker images, volumes, and residual cache$(RESET)"
	docker system prune -af --volumes 2>/dev/null || true

fclean: clean clean-data
	@echo "$(RED)Removing project images and named volumes...$(RESET)"
	docker compose -f $(COMPOSE_FILE) down --rmi all --volumes
	@$(MAKE) clean-docker
	@echo "$(GREEN)System completely sanitized!$(RESET)"

re:
	@echo "$(YELLOW)Rebuilding the entire project...$(RESET)"
	@$(MAKE) fclean
	@$(MAKE) all

.PHONY: all env dirs build up down start stop restart \
images ps status logs logs-% \
db-check wp-check nginx-check network-check ls-containers \
rebuild-all rebuild-% \
db db-root \
clean clean-data clean-docker fclean re