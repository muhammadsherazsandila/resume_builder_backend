# syntax=docker/dockerfile:1

ARG NODE_VERSION=22.18.0
ARG PNPM_VERSION=10.17.1

################################################################################
FROM node:${NODE_VERSION}-alpine as base
WORKDIR /usr/src/app
RUN --mount=type=cache,target=/root/.npm \
    npm install -g pnpm@${PNPM_VERSION}

################################################################################
FROM base as deps
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --prod --frozen-lockfile

################################################################################
FROM deps as build
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

COPY . .

# 🟢 Make sure everything is writable before building
RUN chmod -R 777 /usr/src/app

RUN pnpm run build

################################################################################
FROM base as final
ENV NODE_ENV production

# 🟢 Create app directory & set ownership before switching user
WORKDIR /usr/src/app

# Copy only what’s needed
COPY package.json ./
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/dist ./dist
COPY --from=build /usr/src/app/src ./src
COPY --from=build /usr/src/app/pnpm-lock.yaml ./pnpm-lock.yaml

# 🟢 Fix ownership for node user (important)
RUN chown -R node:node /usr/src/app

USER node

EXPOSE 3001
CMD ["pnpm", "start"]
