.PHONY: build run spec rubocop

# Orchestrated runs write .env.run (gitignored) into worktrees: compose project name and host ports.
# It does not exist in normal checkouts, so nothing changes there.
-include .env.run
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env.run 2>/dev/null)

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

spec: # run RSpec non-interactively in the test environment: make spec SPEC=spec/path_spec.rb (default: all)
	docker-compose run --rm -T -e RACK_ENV=test -e RAILS_ENV=test $(APP_NAME) bundle exec rspec $(SPEC)

rubocop: # run RuboCop non-interactively: make rubocop (all) or make rubocop FILES='path ...'
	docker-compose run --rm -T $(APP_NAME) bundle exec rubocop $(FILES)

rake: ## run a rake task non-interactively (TASK=...)
	docker-compose run --rm -T $(APP_NAME) bundle exec rake $(TASK)

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

