FROM rocker/shiny:4.6.0@sha256:95a0d826be0bfc9bd41300385b35cf0ec074fc6b82cfaa92fddd7c6f6f2fd0dd

USER root
ENV DEBIAN_FRONTEND=noninteractive \
    RENV_CONFIG_PAK_ENABLED=FALSE \
    RENV_CONFIG_CACHE_ENABLED=FALSE \
    RENV_CONFIG_AUTO_SNAPSHOT=FALSE

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential gfortran wget \
      libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev libicu-dev \
      libnlopt-dev libglpk-dev \
      libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
      libpng-dev libjpeg-dev libtiff-dev \
 && rm -rf /var/lib/apt/lists/*

# Locked fs links against system libuv; renv also uses curl for downloads.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libuv1-dev curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/shiny-server/lmplot

# Restore the committed package graph during build, without cache symlinks
# into root's home. Runtime workers read this self-contained project library.
COPY renv.lock .Rprofile ./
COPY renv/activate.R ./renv/activate.R
RUN R --vanilla -s -e "Sys.setenv(LMPLOT_EXPLICIT_BOOTSTRAP='1'); source('renv/activate.R'); renv::restore(prompt = FALSE, clean = TRUE)"

# Only reviewed runtime inputs enter the image, including just the used asset.
COPY app.R ./
COPY R/ ./R/
COPY data/real/ ./data/real/
COPY www/style.css ./www/style.css

# Serve the actual application at /, and start the server directly as shiny.
RUN printf '%s\n' \
      'run_as shiny;' \
      'server {' \
      '  listen 3838;' \
      '  location / {' \
      '    app_dir /srv/shiny-server/lmplot;' \
      '    log_dir /var/log/shiny-server;' \
      '  }' \
      '}' > /etc/shiny-server/shiny-server.conf \
 && chown shiny:shiny /srv/shiny-server/lmplot \
 && install -d -o shiny -g shiny \
      /var/log/shiny-server /var/lib/shiny-server /var/run/shiny-server \
      /var/shiny-server/sockets

# Shiny workers preserve only HOME/LANG/PATH, so configure R's writable cache
# in its site environment rather than relying on container environment vars.
RUN printf '\nR_USER_CACHE_DIR=/tmp/R-cache\n' >> /usr/local/lib/R/etc/Renviron.site
USER shiny
EXPOSE 3838
HEALTHCHECK --interval=10s --timeout=6s --start-period=30s --retries=6 \
  CMD wget --quiet --tries=1 --timeout=5 --output-document=/dev/null http://127.0.0.1:3838/ || exit 1
CMD ["/usr/bin/shiny-server"]
