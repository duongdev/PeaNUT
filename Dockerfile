FROM node:22 AS deps

WORKDIR /app

COPY --link package.json pnpm-lock.yaml* ./

ENV CI=true
RUN npm install -g pnpm

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store pnpm fetch | grep -v "cross-device link not permitted\|Falling back to copying packages from store"

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store pnpm install

FROM node:22 AS build

WORKDIR /app

COPY --link --from=deps /app/node_modules ./node_modules/
COPY . .

RUN npm install -g pnpm && npm run telemetry && npm run build

FROM node:22-alpine AS runner

LABEL org.opencontainers.image.title="PeaNUT"
LABEL org.opencontainers.image.description="A tiny dashboard for Network UPS Tools"
LABEL org.opencontainers.image.url="https://github.com/Brandawg93/PeaNUT"
LABEL org.opencontainers.image.source='https://github.com/Brandawg93/PeaNUT'
LABEL org.opencontainers.image.licenses='Apache-2.0'

COPY --link package.json next.config.js ./

COPY --from=build --link /app/.next/standalone ./
COPY --from=build --link /app/.next/static ./.next/static

ENV NODE_ENV=production
ENV WEB_HOST=0.0.0.0
ENV WEB_PORT=8080

EXPOSE $WEB_PORT

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s \
  CMD wget --no-verbose --tries=1 --spider --no-check-certificate http://$WEB_HOST:$WEB_PORT/api/ping || exit 1

CMD ["npm", "start"]
