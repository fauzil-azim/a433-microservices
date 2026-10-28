# ==============================================================================
# STAGE 1: Build Stage
# Purpose: Install dependencies cleanly in a temporary build environment.
# ==============================================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package manifests first to leverage Docker layer caching
COPY package*.json ./

# Install production-only dependencies and clear npm cache to minimize layer size
RUN npm ci --only=production && npm cache clean --force

# ==============================================================================
# STAGE 2: Production Runtime Stage
# Purpose: Create a lightweight, secure image stripped of build tools.
# ==============================================================================
FROM node:18-alpine AS runner

WORKDIR /app

# SECURITY BEST PRACTICE: Run the application as a non-root user. 
# Node alpine images come with a pre-created 'node' user.
USER node

# Copy production node_modules from the builder stage with correct ownership
COPY --chown=node:node --from=builder /app/node_modules ./node_modules

# Copy application source code with correct ownership
COPY --chown=node:node . .

# Expose the application port
EXPOSE 3001

# Start the application securely as the non-root 'node' user
CMD ["node", "index.js"]