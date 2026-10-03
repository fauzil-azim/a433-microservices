# ---------------------------------------------------------------------------
# Node 14 (official image bundles npm 6.14.x) - keep it that way:
#   package-lock.json was patched by `npm-force-resolutions` and holds
#   `"version": "^4.2.4"` for graceful-fs. npm 8+ rejects it ("Invalid
#   Version"); npm 6 accepts it, and the patch is what lets gulp 3 run on
#   Node >= 12. => never `npm i -g npm@latest` in this image.
#
# Targets:   runtime (default, last stage) = self-contained production image
# ---------------------------------------------------------------------------
ARG NODE_IMAGE=node:14.21.3-alpine3.17

# ---- base ------------------------------------------------------------------
FROM ${NODE_IMAGE} AS base
WORKDIR /app
COPY --chown=node:node . .

# ---- build: gulp -> public/javascripts/dist/dist.min.js ---------------------
FROM base AS build
RUN npm install --production --unsafe-perm && npm run build

# ---- runtime (default target) -----------------------------------------------
FROM base AS runtime
# production => default port 8080, layout.jade serves the minified bundle,
# no stack traces on error pages.
ENV NODE_ENV=production \
    DB_HOST=item-db \
    PORT=8080

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/public/javascripts/dist ./public/javascripts/dist

USER node
EXPOSE 8080

# GET / renders without touching MongoDB, so this checks the HTTP server only.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.PORT||8080)+'/',function(r){process.exit(r.statusCode===200?0:1)}).on('error',function(){process.exit(1)})"

CMD ["npm", "start"]