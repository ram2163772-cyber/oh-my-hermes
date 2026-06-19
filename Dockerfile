FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HERMES_DIR=/home/hermes/.hermes

RUN apt-get update && apt-get install -y \
    curl git bash jq postgresql-client ripgrep \
    ca-certificates gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Vercel CLI
RUN npm install -g vercel

# Supabase CLI (binary install — npm global not supported)
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then SUPABASE_ARCH="linux_amd64"; \
       elif [ "$ARCH" = "arm64" ]; then SUPABASE_ARCH="linux_arm64"; \
       else echo "Unsupported arch: $ARCH" && exit 1; fi \
    && SUPABASE_VERSION=$(curl -s https://api.github.com/repos/supabase/cli/releases/latest | jq -r '.tag_name' | tr -d 'v') \
    && curl -Lo /tmp/supabase.tar.gz "https://github.com/supabase/cli/releases/latest/download/supabase_${SUPABASE_ARCH}.tar.gz" \
    && tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin \
    && rm /tmp/supabase.tar.gz \
    && supabase --version

# Non-root user for runtime isolation
RUN useradd -m -s /bin/bash hermes

# Copy Oh My Hermes
WORKDIR /oh-my-hermes
COPY . .
RUN chmod +x install.sh scripts/bootstrap.sh scripts/verify.sh docker/entrypoint.sh docker/test.sh \
    && chown -R hermes:hermes /oh-my-hermes

USER hermes

ENTRYPOINT ["/oh-my-hermes/docker/entrypoint.sh"]
