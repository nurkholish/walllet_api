# ---------- build stage ----------
FROM ruby:3.3-slim AS builder

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential libpq-dev git curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV BUNDLER_VERSION=2.5.11
RUN gem install bundler -v $BUNDLER_VERSION

COPY Gemfile Gemfile.lock* ./
RUN bundle config set --global path '/usr/local/bundle' \
 && bundle install --jobs 4 --retry 3

# ---------- runtime stage ----------
FROM ruby:3.3-slim AS runtime

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    libpq5 postgresql-client curl \
 && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
RUN groupadd --gid $GID app \
 && useradd --uid $UID --gid app --home /app --shell /bin/bash app

WORKDIR /app
ENV RAILS_ENV=development \
    RACK_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    LANG=C.UTF-8

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /usr/local/bin/bundle /usr/local/bin/bundle
COPY --from=builder /usr/local/bin/bundler /usr/local/bin/bundler
COPY --from=builder /app/Gemfile.lock /app/Gemfile.lock

COPY --chown=app:app . .

RUN rm -rf /app/.bundle /app/vendor/bundle \
 && chmod +x /app/bin/rails /app/bin/docker-entrypoint \
 && mkdir -p /app/log /app/tmp/pids /app/tmp/sockets \
 && chown -R app:app /app/log /app/tmp

USER app
EXPOSE 3000

ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]