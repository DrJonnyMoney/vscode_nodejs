# Use the Kubeflow Code-Server Python image
FROM kubeflownotebookswg/codeserver-python:latest

# Switch to root to make modifications
USER root

# Install basic system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    python3-dev \
    libgl1-mesa-glx \
    ffmpeg \
    gnupg \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install nvm
ENV NVM_DIR /usr/local/nvm
RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && echo 'export NVM_DIR="/usr/local/nvm"' > /etc/profile.d/nvm.sh \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh

# Source nvm in bashrc for interactive use
RUN echo 'export NVM_DIR="/usr/local/nvm"' >> /etc/bash.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/bash.bashrc

# Install useful global npm packages for SvelteKit development including wscat
RUN npm install -g pnpm \
    && npm install -g svelte-check \
    && npm install -g typescript \
    && npm install -g vite \
    && npm install -g wscat

# Install development tools helpful for web development
RUN apt-get update && apt-get install -y \
    jq \
    vim \
    less \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Expose only port 8888 as required by Kubeflow
EXPOSE 8888

# Keep the original entrypoint
ENTRYPOINT ["/init"]
