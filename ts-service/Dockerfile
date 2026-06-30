# Node version matches mise.toml at the repo root (the source of truth).
FROM node:26.4.0-slim

WORKDIR /app

# Install deps first for better layer caching.
COPY package.json ./
RUN npm install

# Application code (asyncapi.yaml and sample-events are mounted at runtime).
COPY . .

# Default command runs the subscriber; override for the publisher CLI.
CMD ["npm", "run", "subscribe"]
