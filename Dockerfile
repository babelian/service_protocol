FROM ruby:2.6.0-alpine3.8

ARG DOCKER_BUILD=1
ENV DOCKER=1

RUN apk add --update \
    build-base \
    ruby-dev \
    bash \
    git \
    && echo "gem: --no-document" > ~/.gemrc \
    && gem install bundler --version 1.17.3

RUN mkdir -p /app
WORKDIR /app
COPY lib/service_protocol/version.rb /app/lib/service_protocol/version.rb
COPY Gemfile Gemfile.lock service_protocol.gemspec /app/
RUN bundle install
COPY . /app