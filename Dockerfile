# ./Dockerfile
FROM ruby:3.3.6 as base

# set some default ENV values for the image
ENV RAILS_LOG_TO_STDOUT 1
ENV RAILS_SERVE_STATIC_FILES 1
ENV EXECJS_RUNTIME Node

# set the app directory var
ENV APP_HOME /api_engine

WORKDIR $APP_HOME
RUN apt-get update -qq
RUN apt-get install -y --no-install-recommends \
  build-essential \
  dumb-init \
  git \
  openssh-client \
  unzip \
  zlib1g-dev \
  default-mysql-client \
  redis-tools

# install bundler
ARG BUNDLER_VERSION=2.5.3
RUN gem install bundler -v "${BUNDLER_VERSION}"
RUN gem install annotate
RUN bundle config set force_ruby_platform true

COPY . $APP_HOME

# RUN gem build rails_base

