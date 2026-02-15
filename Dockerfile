FROM node:22-bookworm

# 1. Setup global dependencies (Root)
RUN corepack enable

# 2. Setup /app directory and permissions
RUN mkdir -p /app && chown node:node /app
WORKDIR /app

# 3. Install system packages (Root)
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# 4. Switch to non-root user
USER node

# 5. Install Bun (as node user)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/home/node/.bun/bin:${PATH}"

# 6. Copy manifest files
COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

# 7. Install dependencies
RUN pnpm install --frozen-lockfile

# 8. Copy source code
COPY --chown=node:node . .

# 9. Build
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# 10. Start gateway (as node user)
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
