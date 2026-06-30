# Ruby version matches mise.toml at the repo root (the source of truth).
# Full image (not -slim): includes the C toolchain needed to build native gem
# extensions — bunny pulls in sorted_set -> rbtree (a C extension).
FROM ruby:4.0.5

WORKDIR /app

# Install gems first for better layer caching.
COPY Gemfile ./
RUN gem install bundler && bundle install

# Application code (asyncapi.yaml and sample-events are mounted at runtime).
COPY . .

# Default command runs the subscriber; override for the publisher CLI.
CMD ["ruby", "subscribe.rb"]
