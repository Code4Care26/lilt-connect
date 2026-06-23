# --- build stage ---
# Node version follows .tool-versions (nodejs 25.x). `npm ci` is reproducible
# from package-lock.json; the build emits the static PWA into dist/.
FROM node:25-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- runtime stage: nginx serving the static build ---
# nginx only serves the SPA + assets. The Ingress routes /api and /sse to the
# Rails and gosse Services *before* a request ever reaches this container, so
# there is no proxying to configure here — only the SPA history fallback.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
