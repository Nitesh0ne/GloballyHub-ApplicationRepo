FROM node:20-bookworm-slim AS builder

WORKDIR /usr/src/app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

RUN npm run build


FROM node:20-bookworm-slim AS runtime

WORKDIR /usr/src/app

ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/static ./static

RUN chown -R node:node /usr/src/app

USER node

CMD ["node", "./dist/index.js"]