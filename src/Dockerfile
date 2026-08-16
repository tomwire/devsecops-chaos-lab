# =============================================================================
# DevSecOps Chaos Lab — Multi-stage Dockerfile
# ===========================================================================
# Stage 1: Build (node:20-alpine) — install deps, validate app
# Stage 2: Production (gcr.io/distroless/nodejs20-debian12) — non-root, minimal

FROM node:20-alpine AS build

WORKDIR /app

COPY package.json ./
COPY package-lock.json ./
RUN npm ci

COPY . .

# ---------------------------------------------------------------------------
# Validation step — if this fails, image is rejected before it ships
# ---------------------------------------------------------------------------
RUN node -e "require('./app.js'); process.exit(0)" && echo "✅ App loads successfully"

# ---------------------------------------------------------------------------
# Stage 2: Distroless (no shell, no package manager, no node_modules tree)
# Runs as non-root user
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/nodejs20-debian12 AS production

LABEL org.opencontainers.image.title="sample-app"
LABEL org.opencontainers.image.description="DevSecOps Chaos Lab sample application"
LABEL org.opencontainers.image.source="https://github.com/twire/devsecops-chaos-lab"

WORKDIR /app

COPY --from=build --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=build --chown=nonroot:nonroot /app/package.json ./package.json
COPY --from=build --chown=nonroot:nonroot /app/app.js ./app.js

USER nonroot

EXPOSE 3000

ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/healthz || exit 1

ENTRYPOINT ["node", "app.js"]
