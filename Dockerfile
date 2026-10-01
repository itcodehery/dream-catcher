# ==========================================
# Stage 1: Build & install dependencies
# ==========================================
FROM node:22-bookworm-slim AS builder

WORKDIR /app

# Install build dependencies in case native modules need compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy package manifests
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# ==========================================
# Stage 2: Production runtime
# ==========================================
FROM node:22-bookworm-slim AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3001
ENV DATABASE_PATH=/app/data/dreams.db

# Create directory for persistent SQLite database and set permissions
RUN mkdir -p /app/data && chown -R node:node /app

# Copy production node_modules from builder
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy application source code
COPY --chown=node:node . .

# Ensure data directory and files are owned by node user
RUN chown -R node:node /app

# Use unprivileged user for security
USER node

# Expose server port
EXPOSE 3001

# Health check using Node's native fetch API
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3001) + '/').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Start the application
CMD ["node", "server.js"]
