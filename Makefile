# **************************************************************************** #
# VARIABLES

NAME          = inception
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
	@echo "$(YELLOW)Creating directory for MariaDB in $(DATA_DIR)/mariadb...$(RESET)"
	@mkdir -p $(DATA_DIR)/mariadb

$(DATA_DIR)/wordpress:
	@echo "$(YELLOW)Creating directory for WordPress in $(DATA_DIR)/wordpress...$(RESET)"
	@mkdir -p $(DATA_DIR)/wordpress

build: $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	@echo "$(GREEN)Compiling images in docker...$(RESET)"
	docker compose -f $(COMPOSE_FILE) build

up:
	@echo "$(GREEN)Creating and starting containers in the background...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d
	@echo "$(YELLOW) Waiting for WordPress and PHP-FPM to be ready...$(RESET)"
	@until docker exec wordpress wp core is-installed --allow-root --path=/var/www/html >/dev/null 2>&1; do \
		sleep 2; \
	done
	@printf "$$ASCII_ART\n"
	@echo "$(GREEN)Infrastructure is now active! Access at https://ozamora.42.fr$(RESET)"

down:
	@echo "$(YELLOW)Stopping containers and removing images and volumes...$(RESET)"
	docker compose -f $(COMPOSE_FILE) down

start:
	@echo "$(GREEN)Starting containers...$(RESET)"
	docker compose -f $(COMPOSE_FILE) start

stop:
	@echo "$(YELLOW)Stopping containers...$(RESET)"
	docker compose -f $(COMPOSE_FILE) stop

restart:
	@echo "$(YELLOW)Restarting containers...$(RESET)"
	docker compose -f $(COMPOSE_FILE) restart

status:
	@echo "$(YELLOW)Displaying status of containers...$(RESET)"
	docker ps

logs:
	@echo "$(YELLOW)Displaying logs of containers...$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f

logs-mariadb:
	@echo "$(YELLOW)Displaying logs of MariaDB...$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f mariadb

logs-wordpress:
	@echo "$(YELLOW)Displaying logs of WordPress...$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f wordpress

logs-nginx:
	@echo "$(YELLOW)Displaying logs of Nginx...$(RESET)"
	docker compose -f $(COMPOSE_FILE) logs -f nginx

reset-data:
	@echo "$(YELLOW)Resetting all data...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build mariadb wordpress nginx

reset-mariadb:
	@echo "$(YELLOW)Resetting MariaDB data...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build mariadb

reset-wordpress:
	@echo "$(YELLOW)Resetting WordPress data...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build wordpress

reset-nginx:
	@echo "$(YELLOW)Resetting Nginx data...$(RESET)"
	docker compose -f $(COMPOSE_FILE) up -d --no-deps --build nginx

db:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as wpuser...$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD"'	

db-root:
	@echo "$(CYAN)[$(NAME)] Accessing MariaDB as root...$(RESET)"
	docker exec -it mariadb sh -c 'mariadb -u root -p"$$MYSQL_ROOT_PASSWORD"'

db-check:
	@echo "$(CYAN)[$(NAME)] Databases:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" -e "SHOW DATABASES;"'
	@echo "\n$(CYAN)[$(NAME)] Users:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$MYSQL_ROOT_PASSWORD" -e "SELECT User, Host FROM mysql.user;"'
	@echo "\n$(CYAN)[$(NAME)] Grants:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR '\''ozamora'\''@'\''%'\'';"'
	@echo "\n$(CYAN)[$(NAME)] Grants for root:$(RESET)"
	docker exec mariadb sh -c 'mariadb -u root -p"$$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR '\''root'\''@'\''localhost'\'';"'

wp-check:
	@echo "\n$(CYAN)[WordPress] Users list and roles:$(RESET)"
	@docker exec wordpress wp user list --allow-root --path=/var/www/html
	@echo "\n$(CYAN)[WordPress] URLs that are configured in the DB:$(RESET)"
	@docker exec wordpress wp option get siteurl --allow-root --path=/var/www/html

clean:
	@echo "$(RED)Stopping and removing containers, local images and networks..."
	@echo "$(RED)(Equivalent to: stop, rm, network rm, volume rm, rmi)$(RESET)"
	@if [ -f $(COMPOSE_FILE) ]; then \
		docker compose -f $(COMPOSE_FILE) down --rmi all --volumes 2>/dev/null || true; \
	fi

clean-data:
	@echo "$(RED)Removing data directories in $(DATA_DIR)...$(RESET)"
	@sudo rm -rf $(DATA_DIR)/mariadb/*
	@sudo rm -rf $(DATA_DIR)/wordpress/*

clean-docker:
	@echo "$(RED)Removing all dangling Docker images and residual cache...$(RESET)"
	@docker image prune -af 2>/dev/null || true

fclean: clean clean-data clean-docker
	@echo "$(GREEN)System completely sanitized!$(RESET)"

re: fclean all

.PHONY: all build up down start stop status \
logs logs-mariadb logs-wordpress logs-nginx \
reset-data reset-mariadb reset-wordpress reset-nginx \
clean clean-data clean-doker fclean re