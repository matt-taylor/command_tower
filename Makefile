.PHONY: build run

APP_NAME=engine

build:
	docker-compose build

bundle: #
	docker-compose run $(APP_NAME) bundle install

setup: build bundle db_reset annotate clean # Set up the service

db_reset: # Blows away db and sets it up with seed data
	docker-compose run --rm $(APP_NAME) bin/rails db:reset

migrate: # Blows away db and sets it up with seed data
	docker-compose run --rm $(APP_NAME) bin/rails db:migrate

setup_db: # sets up db from empty state
	docker-compose run --rm $(APP_NAME) bin/rails db:setup

bash: # get a bash container
	docker-compose run --rm -e RACK_ENV=development $(APP_NAME) bash

bash_test: # get a bash container
	docker-compose run --rm -e RACK_ENV=test $(APP_NAME) bash

annotate: # annotate models
	docker-compose run --rm -e RACK_ENV=development $(APP_NAME) bundle exec annotate --models

down: # Bring down the service
	docker-compose down

clean: # Clean up stopped/exited containers
	docker-compose rm -f

ps: # show running containers for the service
	docker-compose ps

c console: # open up a console
	docker-compose run --rm $(APP_NAME) bin/rails c

clear_pid:
	 touch rails_app/tmp/pids/server.pid && rm -f rails_app/tmp/pids/server.pid

s server: clear_pid #stop_sidekiq
	docker-compose run --rm -e RACK_ENV=development --service-ports $(APP_NAME)

stop_sidekiq:
	docker-compose stop sidekiq

