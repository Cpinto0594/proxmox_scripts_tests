# ---- build: Markdown -> static HTML ----
FROM python:3.13-slim AS build
# Tested with 0.0.68. Bump deliberately and rebuild locally first.
ARG ZENSICAL_VERSION="0.0.68"
RUN pip install --no-cache-dir "zensical${ZENSICAL_VERSION:+==${ZENSICAL_VERSION}}"
WORKDIR /src
COPY zensical.toml ./
COPY docs ./docs
RUN zensical build --clean

# ---- runtime: static files only, non-root nginx on :8080 ----
FROM nginxinc/nginx-unprivileged:alpine
COPY --from=build /src/site /usr/share/nginx/html
EXPOSE 8080
