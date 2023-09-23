FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install --immutable
COPY --chown=node:node . .
USER node

FROM node:20-alpine AS builder
WORKDIR /app
COPY --chown=node:node --from=deps /app/node_modules ./node_modules
COPY --chown=node:node . .

RUN yarn build
USER node

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

COPY --chown=node:node --from=builder /app/node_modules ./node_modules
COPY --chown=node:node --from=builder /app/dist ./dist
USER node

EXPOSE 3000
ENV PORT 3000

CMD [ "node", "dist/main.js" ]