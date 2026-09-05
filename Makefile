# **************************************************************************** #
# VARIABLES

NAME          = Inception
COMPOSE_FILE  = srcs/docker-compose.yml
DATA_DIR      = /home/$(USER)/data

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

build: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
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
	@echo "$(GREEN)Infrastructure is now active! Access at https://ozamora.42.fr$(RESET)"

down:
	@echo "$(YELLOW)Docker down: stopping containers and removing images and volumes$(RESET)"
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

status:
	@echo "$(YELLOW)Displaying status of images$(RESET)"
	docker images
	@echo "$(YELLOW)\nDisplaying status of containers$(RESET)"
	docker ps

# **************************************************************************** #
# Rules for displaying logs of the containers

logs:
	@echo "$(YELLOW)Displaying logs of containers$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f

logs-mariadb:
	@echo "$(YELLOW)Displaying logs of MariaDB$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f mariadb

logs-wordpress:
	@echo "$(YELLOW)Displaying logs of WordPress$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f wordpress

logs-nginx:
	@echo "$(YELLOW)Displaying logs of Nginx$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f nginx

# **************************************************************************** #
# Rules for rebuilding services preserving persistent data
# Useful for reapplying changes in Dockerfiles or configuration files without losing data

rebuild-data:
	@echo "$(YELLOW)Rebuilding all services$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build mariadb wordpress nginx

rebuild-mariadb:
	@echo "$(YELLOW)Rebuilding MariaDB service$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build mariadb

rebuild-wordpress:
	@echo "$(YELLOW)Rebuilding WordPress service$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build wordpress

rebuild-nginx:
	@echo "$(YELLOW)Rebuilding Nginx service$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build nginx

# **************************************************************************** #
# Rules for accessing MariaDB and WordPress, checking their status and listing critical directories

db:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as wpuser (interactive shell)$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u "$$MYSQL_USER" -p"$$(cat /run/secrets/MYSQL_PASSWORD)"'

db-root:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as root (interactive shell)$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u root -p"$$(cat /run/secrets/MYSQL_ROOT_PASSWORD)"'

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
	@docker exec wordpress wp user list --allow-root --path=/var/www/html
	@echo "\n$(CYAN)[WordPress] URLs that are configured in the DB:$(RESET)"
	@docker exec wordpress wp option get siteurl --allow-root --path=/var/www/html

ls-containers:
	@echo "$(CYAN)[MariaDB] Critical Directories (/var/lib/mysql, /run/mysqld)$(RESET)"
	@docker exec mariadb ls -ld /var/lib/mysql /run/mysqld 2>/dev/null || echo "MariaDB is not running."
	@echo "\n$(CYAN)[WordPress] Root Directory (/var/www/html)$(RESET)"
	@docker exec wordpress ls -ld /var/www/html 2>/dev/null || echo "WordPress is not running."
	@echo "\n$(CYAN)[NGINX] Certificates (/etc/nginx/ssl) and Root Directory (/var/www/html)$(RESET)"
	@docker exec nginx ls -la /etc/nginx/ssl 2>/dev/null || echo "NGINX is not running."
	@docker exec nginx ls -ld /var/www/html 2>/dev/null || true

# **************************************************************************** #
# Rules for cleaning up containers, images, and data

clean:
	@echo "$(RED)Stopping and removing containers, local images and networks"
	@echo "$(RED)(Equivalent to: stop, rm, network rm, volume rm, rmi)$(RESET)"
	@if [ -f $(COMPOSE_FILE) ]; then \
		docker compose -f $(COMPOSE_FILE) down --rmi all --volumes 2>/dev/null || true; \
	fi

clean-data:
	@echo "$(RED)Removing data directories in $(DATA_DIR)$(RESET)"
	@sudo rm -rf $(DATA_DIR)/mariadb/*
	@sudo rm -rf $(DATA_DIR)/wordpress/*

clean-docker:
	@echo "$(RED)Removing all dangling Docker images and residual cache$(RESET)"
	@docker image prune -af 2>/dev/null || true

fclean: clean clean-data clean-docker
	@echo "$(GREEN)System completely sanitized!$(RESET)"

re: fclean all

.PHONY: all build up down start stop restart status \
logs logs-mariadb logs-wordpress logs-nginx \
reset-data reset-mariadb reset-wordpress reset-nginx \
clean clean-data clean-doker fclean re