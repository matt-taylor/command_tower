# 01 — Docker, Make, Compose

## Purpose

Author the local toolchain **before** any Rails app exists. After this step you can `make help` and `make build` on an empty repository. Ruby is only inside the image.

## Prerequisites

- Docker Desktop (or equivalent) with the Compose plugin
- Make
- Git
- Empty (or nearly empty) host repository

Do **not** install Ruby, Bundler, or Rails on the Mac.

## Files the host creates

| File | Role |
|------|------|
| `Dockerfile` | Ruby image: Bundler, MariaDB client, Node (asset/JS tooling if needed) |
| `docker-compose.yml` | `api`, MariaDB **10.11+**, Redis |
| `Makefile` | Operator surface: `build`, `rails-new`, `rails`, `migrate`, `doctor`, … |
| `.dockerignore` | Keep the build context small |
| `.env` (gitignored) | Local secrets later ([`04-secrets-and-env.md`](04-secrets-and-env.md)); create a stub if Compose interpolates vars |

The database in **this recipe** is MariaDB 10.11+ with `utf8mb4` / `utf8mb4_unicode_ci`. That is a host choice documented here. Do not copy the gem’s engine-dev compose (`mysql:latest`).

Redis is required for CommandTower cache/features that expect it. Optional `worker` is only if the host uses Solid Queue (add after the app exists).

## Procedure

### 1. `.dockerignore`

```
.git
log
tmp
.env
coverage
vendor/bundle
node_modules
.DS_Store
```

### 2. `Dockerfile`

Use an MRI image CommandTower’s doctor accepts (Rails **>= 7 and < 9**). A current floor that matches engine CI is Ruby **4.0.x** and Rails **8.1**. Do not freeze an older patch than the gem you will pin in step 03.

The image must **bind Puma on `0.0.0.0`**. Binding `127.0.0.1` inside the container is not reachable from the Mac.

```dockerfile
FROM ruby:4.0.1

ENV RAILS_LOG_TO_STDOUT=1
ENV BUNDLE_PATH=/usr/local/bundle
ENV BUNDLE_JOBS=4

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    default-libmysqlclient-dev \
    default-mysql-client \
    libyaml-dev \
    pkg-config \
    redis-tools \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gemfile does not exist until `make rails-new`. Copy the context; install gems when present.
COPY . .
RUN if [ -f Gemfile ]; then bundle install; fi

EXPOSE 3000
CMD ["bundle", "exec", "bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

Until [`02-create-the-rails-app.md`](02-create-the-rails-app.md) runs, there is **no** `Gemfile`. That is expected. `make build` still produces an image with Ruby, Bundler, and the MariaDB client. `make rails-new` uses that image.

After `rails new` you will have a Gemfile; rebuild so `bundle install` during image build caches gems. Day-to-day `make bundle` still refreshes gems in the running volume.

### 3. `docker-compose.yml`

```yaml
services:
  api:
    build: .
    working_dir: /app
    command: bundle exec bin/rails server -b 0.0.0.0 -p 3000
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    ports:
      - "3000:3000"
    environment:
      RAILS_ENV: development
      DATABASE_URL: mysql2://app:app@db:3306/app_development
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY_BASE: ${SECRET_KEY_BASE:-dev-secret-key-base-change-me}
      SIGNUP_SESSION_JWT_SECRET: ${SIGNUP_SESSION_JWT_SECRET:-dev-signup-session-change-me}
      PASSWORD_RECOVERY_SESSION_JWT_SECRET: ${PASSWORD_RECOVERY_SESSION_JWT_SECRET:-dev-password-recovery-change-me}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS:-http://localhost:8081,http://localhost:8082,http://localhost:19006}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    stdin_open: true
    tty: true

  db:
    image: mariadb:10.11
    environment:
      MARIADB_ROOT_PASSWORD: root
      MARIADB_DATABASE: app_development
      MARIADB_USER: app
      MARIADB_PASSWORD: app
    ports:
      - "3306:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 5s
      retries: 20

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  bundle_cache:
  mariadb_data:
```

Rename `app_development` / user / password to product names when you have them. Keep utf8mb4.

`command:` (and the Dockerfile `CMD`) must use `-b 0.0.0.0`. Without it, `make server` is not reachable from the Mac or from an Expo app on the host OS.

Published port **3000** is this recipe’s default for a single local API. The frontend `HostConfig` API origin must use the **same** host-published port. A second Command Tower API on this machine publishes a different host port. Engine-dev compose in this gem uses different ports; ignore it.

`CORS_ALLOWED_ORIGINS` in the sample (`8081`, `8082`, `19006`) is one web product’s origins. A second local web app uses its own Expo port. Change that origin, this API’s published port, and `config.application.url` (step 08) together. The list is consumed in [`11-auth-client-path.md`](11-auth-client-path.md). `curl` on the Mac does not need CORS.

### 4. `Makefile`

Generic operator surface. `COMPOSE` is the only Compose invocation.

```makefile
.PHONY: help build bundle setup fresh rebuild rails-new rails db-prepare migrate doctor \
	bash console runner server s halt down down-v rspec test spec rubocop

COMPOSE := docker compose
API    := $(COMPOSE) run --rm api
API_T  := $(COMPOSE) run --rm -T api

help:
	@echo "build       Build the api image"
	@echo "bundle      bundle install in the container"
	@echo "setup       build + db-prepare"
	@echo "fresh       down-v + setup"
	@echo "rebuild     build --no-cache + bundle"
	@echo "rails-new   rails new (API) inside the container"
	@echo "rails       Forward to bin/rails (ARGS=...)"
	@echo "db-prepare  db:prepare"
	@echo "migrate     db:migrate"
	@echo "doctor      command_tower:doctor"
	@echo "bash        Shell in api"
	@echo "console     rails console"
	@echo "runner      rails runner CMD='...'"
	@echo "server / s  Foreground api server"
	@echo "halt        Stop compose"
	@echo "down        compose down"
	@echo "down-v      compose down -v (destroys DB volume)"
	@echo "rspec/test  rspec"
	@echo "spec        rspec SPEC=path"
	@echo "rubocop     rubocop"

build:
	$(COMPOSE) build api

bundle:
	$(API) bundle install

setup: build db-prepare

fresh: down-v setup

rebuild:
	$(COMPOSE) build --no-cache api
	$(MAKE) bundle

# Chicken-and-egg: image has Ruby; Gemfile may not exist yet.
# Doctor accepts Rails >= 7 and < 9. Prefer 8.1 to match current engine CI.
RAILS_NEW_VERSION ?= ~> 8.1.0
rails-new:
	$(API) bash -lc 'gem install rails -v "$(RAILS_NEW_VERSION)" --no-document && rails new . --api --database=mysql --skip-git --force'

rails:
	$(COMPOSE) run --rm -e SKIP_MOUNT -e SKIP_CONFIGURE -e FORCE api bundle exec bin/rails $(ARGS)

db-prepare:
	$(API) bundle exec bin/rails db:prepare

migrate:
	$(API) bundle exec bin/rails db:migrate

doctor:
	$(API) bundle exec bin/rails command_tower:doctor

bash:
	$(COMPOSE) run --rm api bash

console:
	$(API) bundle exec bin/rails console

runner:
	$(API) bundle exec bin/rails runner "$(CMD)"

server s:
	$(COMPOSE) up api

halt:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

down-v:
	$(COMPOSE) down -v

rspec test:
	$(API_T) bundle exec rspec

spec:
	$(API_T) bundle exec rspec $(SPEC)

rubocop:
	$(API_T) bundle exec rubocop
```

`rails-new` installs the Rails **gem inside the ephemeral container** and writes the app onto the mounted `/app`. That is still Docker-only: the Mac never runs `gem` or `rails`.

After the app exists, prefer `make rails ARGS='…'` over re-running `rails-new`.

Flags such as `SKIP_MOUNT=1` belong on the Make line. The `rails` recipe forwards `SKIP_MOUNT`, `SKIP_CONFIGURE`, and `FORCE` into the container:

```bash
SKIP_MOUNT=1 make rails ARGS='command_tower:install'
```

### 5. Build

```bash
make help
make build
```

`make build` may warn that `Gemfile` is missing. That is expected until step 02.

## Stop

`make help` prints the operator surface. `make build` produces an `api` image with Ruby. There is still no Rails application. Next: [`02-create-the-rails-app.md`](02-create-the-rails-app.md).
