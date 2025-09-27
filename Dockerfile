FROM ruby:3.1-alpine

# Installe les dépendances système
RUN apk add --no-cache \
    build-base \
    git \
    curl \
    wget \
    ca-certificates \
    openssl-dev \
    libxml2-dev \
    libxslt-dev \
    zlib-dev

# Définit le répertoire de travail
WORKDIR /app

# Clone le repository et installe les dépendances
RUN git clone https://github.com/ryanfb/academia-dl.git . && \
    gem install nokogiri open_uri_redirections addressable && \
    chmod +x academia-dl.rb

# Crée le répertoire de téléchargement
RUN mkdir -p /downloads

# Définit le volume
VOLUME ["/downloads"]

# Script wrapper simple et fonctionnel
RUN echo '#!/bin/sh' > /usr/local/bin/run-academia-dl && \
    echo 'if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ $# -eq 0 ]; then' >> /usr/local/bin/run-academia-dl && \
    echo '  echo "=== Academia-dl Docker ==="' >> /usr/local/bin/run-academia-dl && \
    echo '  echo "Usage: <command> <academia.edu_url>"' >> /usr/local/bin/run-academia-dl && \
    echo '  echo "Exemple: docker-compose run --rm academia-dl '\''https://www.academia.edu/123456/Paper'\''"' >> /usr/local/bin/run-academia-dl && \
    echo '  exit 0' >> /usr/local/bin/run-academia-dl && \
    echo 'fi' >> /usr/local/bin/run-academia-dl && \
    echo 'cd /downloads' >> /usr/local/bin/run-academia-dl && \
    echo 'echo "Téléchargement depuis: $1"' >> /usr/local/bin/run-academia-dl && \
    echo 'echo "Destination: /downloads"' >> /usr/local/bin/run-academia-dl && \
    echo 'ruby /app/academia-dl.rb "$@"' >> /usr/local/bin/run-academia-dl && \
    chmod +x /usr/local/bin/run-academia-dl

ENTRYPOINT ["/usr/local/bin/run-academia-dl"]
CMD ["--help"]
