FROM elixir:1.19

# Install git, Node.js (for esbuild/tailwind), and other dependencies
RUN apt-get update && \
    apt-get install -y git build-essential ca-certificates curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Configure git for large repos
RUN git config --global http.postBuffer 524288000 && \
    git config --global http.version HTTP/1.1

# Set environment
ENV MIX_ENV=prod
ENV LOCAL_METASTATIC=1
ENV PHX_SERVER=true
ENV XLA_TARGET=cpu
ENV EXLA_TARGET=host

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

ARG REVALIDATE_MIX_CACHE=1

# Clone Metastatic (ragex dependency)
RUN mkdir -p /tools/metastatic && \
    git clone https://github.com/Oeditus/metastatic.git /tools/metastatic && \
    cd /tools/metastatic && \
    LATEST_TAG=$(git describe --tags --abbrev=0) && \
    git checkout $LATEST_TAG

# Clone Ragex
RUN mkdir -p /tools/ragex && \
    git clone https://github.com/Oeditus/ragex.git /tools/ragex && \
    cd /tools/ragex && \
    LATEST_TAG=$(git describe --tags --abbrev=0) && \
    git checkout $LATEST_TAG

# Clone Yeesh
RUN mkdir -p /tools/yeesh && \
    git clone https://github.com/Oeditus/yeesh.git /tools/yeesh && \
    cd /tools/yeesh && \
    LATEST_TAG=$(git describe --tags --abbrev=0) && \
    git checkout $LATEST_TAG

# Clone ragex_yeesh
RUN git clone https://github.com/Oeditus/ragex_yeesh.git /app && \
    cd /app && \
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD") && \
    git checkout $LATEST_TAG 2>/dev/null || true

# Install npm deps for xterm
RUN npm install --prefix /app/assets

# Get and compile deps
RUN LOCAL_RAGEX=1 mix deps.get && \
    LOCAL_RAGEX=1 mix compile

# Build assets
RUN LOCAL_RAGEX=1 mix assets.deploy

# Pre-download Bumblebee embedding model
ENV BUMBLEBEE_CACHE_DIR=/root/.cache/bumblebee
RUN LOCAL_RAGEX=1 mix ragex.models.download --quiet || \
    echo "Warning: Model download failed, models will be downloaded on first use"

# The target codebase is mounted here
VOLUME /workspace

EXPOSE 4000

CMD ["mix", "phx.server"]
