# syntax=docker/dockerfile:1
# check=error=true

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.1
FROM ruby:$RUBY_VERSION-alpine AS base

LABEL fly_launch_runtime="rails"

# Rails app lives here
WORKDIR /rails

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler && \
    rm -rf ~/.cache/gem

# Install base packages
RUN apk add --no-cache curl jemalloc postgresql-client tzdata

# Set production environment
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"


# Throw-away build stages to reduce size of final image
FROM base AS prebuild

# Install packages needed to build gems and node modules
RUN apk add --no-cache build-base git gyp libpq-dev pkgconfig python3 yaml-dev


FROM prebuild AS node

# Install Node.js
ARG NODE_VERSION=22.4.0
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64-musl.tar.gz | tar xz -C /tmp/ && \
    mkdir /usr/local/node && \
    cp -rp /tmp/node-v${NODE_VERSION}-linux-x64-musl/* /usr/local/node/ && \
    rm -rf /tmp/node-v${NODE_VERSION}-linux-x64-musl

# Install node modules
COPY package.json ./
RUN npm install


FROM prebuild AS build

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy node modules
COPY --from=node /rails/node_modules /rails/node_modules
COPY --from=node /usr/local/node /usr/local/node
ENV PATH=/usr/local/node/bin:$PATH

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Adjust binfiles to set current working directory
RUN grep -l '#!/usr/bin/env ruby' /rails/bin/* | xargs sed -i '/^#!/aDir.chdir File.expand_path("..", __dir__)'

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# KEEP ME: Cleanup before copying build to final stage
RUN rm -rf node_modules log/*

# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apk add --no-cache gzip libpq

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN addgroup --system --gid 1000 rails && \
    adduser --system rails --uid 1000 --ingroup rails --home /home/rails --shell /bin/sh rails && \
    chown -R 1000:1000 db log tmp
USER 1000:1000

# Entrypoint sets up the container.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
