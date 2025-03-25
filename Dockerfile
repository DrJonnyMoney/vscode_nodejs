#
# NOTE: Use the Makefiles to build this image correctly.
#
FROM kubeflownotebookswg/codeserver:latest

ARG TARGETARCH=amd64

USER root

# Build arguments for software versions
ARG CODESERVER_PYTHON_VERSION=2025.0.0
ARG CODESERVER_JUPYTER_VERSION=2024.11.0
ARG IPYKERNEL_VERSION=6.29.5
ARG MINIFORGE_VERSION=24.11.3-0
ARG PIP_VERSION=24.3.1
ARG PYTHON_VERSION=3.11.11
ARG NVM_VERSION=0.39.4
ARG NODE_VERSION=18

# Set up environment for Conda
ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
RUN mkdir -pv ${CONDA_DIR} \
 && chmod 2775 ${CONDA_DIR} \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> ${HOME}/.bashrc \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> /etc/profile \
 && echo "conda activate base" >> ${HOME}/.bashrc \
 && echo "conda activate base" >> /etc/profile \
 && chown -R ${NB_USER}:${NB_GID} ${CONDA_DIR} \
 && chown -R ${NB_USER}:${USERS_GID} ${HOME}

# Copy the 02-conda-init file into the container's initialization folder
COPY --chmod=755 02-conda-init /etc/cont-init.d/02-conda-init

USER $NB_UID

# Install Python (Miniforge), pip, and update Python packages
RUN case "${TARGETARCH}" in \
      amd64) MINIFORGE_ARCH="x86_64" ;; \
      arm64) MINIFORGE_ARCH="aarch64" ;; \
      ppc64le) MINIFORGE_ARCH="ppc64le" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh" -o /tmp/Miniforge3.sh \
 && curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh.sha256" -o /tmp/Miniforge3.sh.sha256 \
 && echo "$(awk '{print $1}' /tmp/Miniforge3.sh.sha256)  /tmp/Miniforge3.sh" | sha256sum -c - \
 && rm /tmp/Miniforge3.sh.sha256 \
 && /bin/bash /tmp/Miniforge3.sh -b -f -p ${CONDA_DIR} \
 && rm /tmp/Miniforge3.sh \
 && conda config --system --set auto_update_conda false \
 && conda config --system --set show_channel_urls true \
 && echo "python ==${PYTHON_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
 && conda install -y -q python=${PYTHON_VERSION} pip=${PIP_VERSION} \
 && conda update -y -q --all \
 && conda clean -a -f -y

# Install ipykernel (required for the Jupyter code-server extension)
RUN echo "ipykernel ==${IPYKERNEL_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
 && conda install -y -q ipykernel==${IPYKERNEL_VERSION} \
 && conda clean -a -f -y

# Install Python dependencies from requirements.txt (if present)
COPY --chown=${NB_USER}:${NB_GID} requirements.txt /tmp
RUN python3 -m pip install -r /tmp/requirements.txt --quiet --no-cache-dir \
 && rm -f /tmp/requirements.txt

# Install code-server extensions for Python and Jupyter
RUN code-server --install-extension "ms-python.python@${CODESERVER_PYTHON_VERSION}" --force \
 && code-server --install-extension "ms-toolsai.jupyter@${CODESERVER_JUPYTER_VERSION}" --force \
 && code-server --list-extensions --show-versions

# ---------------------------
# Install NVM, Node.js, and global Svelte development tools
# ---------------------------
# Switch to the notebook user (if not already)
USER $NB_UID
# Install NVM for the notebook user
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
 && echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.bashrc \
 && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm' >> $HOME/.bashrc
# Load nvm and install the specified Node version; set it as default
RUN bash -c "source $HOME/.nvm/nvm.sh && nvm install ${NODE_VERSION} && nvm alias default ${NODE_VERSION}"
# Ensure the Node.js binary directory is in PATH for future shells
RUN echo 'export PATH="$HOME/.nvm/versions/node/$(nvm version default)/bin:$PATH"' >> $HOME/.bashrc
# Install global npm packages for Svelte development (e.g., SvelteKit and Vite)
RUN bash -c "source $HOME/.nvm/nvm.sh && npm install -g @sveltejs/kit vite"

# Optionally copy additional home directory contents (if needed)
# COPY --chown=${NB_USER}:${NB_GID} home/. ${HOME}/

# s6 - 01-copy-tmp-home: copy the temporary home directory to $HOME at runtime.
RUN cp -p -r -T "${HOME}" "${HOME_TMP}" \
 && chmod -R g=u "${HOME_TMP}"

# Expose the port used by code-server (if not already exposed by the base image)
EXPOSE 8888
