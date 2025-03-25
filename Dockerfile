# Using the Kubeflow codeserver image directly
FROM kubeflownotebookswg/codeserver:latest

# Set a default value for TARGETARCH if not provided
ARG TARGETARCH="amd64"

USER root

# args - software versions
ARG CODESERVER_PYTHON_VERSION=2025.0.0
ARG CODESERVER_JUPYTER_VERSION=2024.11.0
ARG IPYKERNEL_VERSION=6.29.5
ARG MINIFORGE_VERSION=24.11.3-0
ARG PIP_VERSION=24.3.1
ARG PYTHON_VERSION=3.11.11

# setup environment for conda
ENV CONDA_DIR /opt/conda
ENV PATH "${CONDA_DIR}/bin:${PATH}"
RUN mkdir -pv ${CONDA_DIR} \
 && chmod 2775 ${CONDA_DIR} \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> ${HOME}/.bashrc \
 && echo ". /opt/conda/etc/profile.d/conda.sh" >> /etc/profile \
 && echo "conda activate base" >> ${HOME}/.bashrc \
 && echo "conda activate base" >> /etc/profile \
 && chown -R ${NB_USER}:${NB_GID} ${CONDA_DIR} \
 && chown -R ${NB_USER}:${USERS_GID} ${HOME}

USER $NB_UID

# install - conda, pip, python (with explicit architecture setting)
RUN MINIFORGE_ARCH="x86_64" \
 && curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh" -o /tmp/Miniforge3.sh \
 && curl -fsSL "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-${MINIFORGE_ARCH}.sh.sha256" -o /tmp/Miniforge3.sh.sha256 \
 && echo "$(cat /tmp/Miniforge3.sh.sha256 | awk '{ print $1; }')  /tmp/Miniforge3.sh" | sha256sum -c - \
 && rm /tmp/Miniforge3.sh.sha256 \
 && /bin/bash /tmp/Miniforge3.sh -b -f -p ${CONDA_DIR} \
 && rm /tmp/Miniforge3.sh \
 && conda config --system --set auto_update_conda false \
 && conda config --system --set show_channel_urls true \
 && echo "python ==${PYTHON_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
 && conda install -y -q \
    python=${PYTHON_VERSION} \
    pip=${PIP_VERSION} \
 && conda update -y -q --all \
 && conda clean -a -f -y

# install - ipykernel
# NOTE: we need this for jupyter codeserver extension to work
RUN echo "ipykernel ==${IPYKERNEL_VERSION}" >> ${CONDA_DIR}/conda-meta/pinned \
 && conda install -y -q \
    ipykernel==${IPYKERNEL_VERSION} \
 && conda clean -a -f -y

# install - requirements.txt
COPY --chown=${NB_USER}:${NB_GID} requirements.txt /tmp
RUN python3 -m pip install -r /tmp/requirements.txt --quiet --no-cache-dir \
 && rm -f /tmp/requirements.txt

# install - codeserver extensions
RUN code-server --install-extension "ms-python.python@${CODESERVER_PYTHON_VERSION}" --force \
 && code-server --install-extension "ms-toolsai.jupyter@${CODESERVER_JUPYTER_VERSION}" --force \
 && code-server --list-extensions --show-versions

# Skip copying home files since directory doesn't exist
# COPY --chown=${NB_USER}:${NB_GID} home/. ${HOME}/

# Create and configure 02-conda-init file
USER root
RUN mkdir -p /etc/cont-init.d
RUN echo '#!/usr/bin/with-contenv bash' > /etc/cont-init.d/02-conda-init \
 && echo 'conda init bash' >> /etc/cont-init.d/02-conda-init \
 && echo 'conda activate base' >> /etc/cont-init.d/02-conda-init \
 && chmod +x /etc/cont-init.d/02-conda-init

# s6 - 01-copy-tmp-home
# NOTE: the contents of $HOME_TMP are copied to $HOME at runtime
#       this is a workaround because a PVC will be mounted at $HOME
#       and the contents of $HOME will be hidden
USER $NB_UID
RUN cp -p -r -T "${HOME}" "${HOME_TMP}" \
    # give group same access as user (needed for OpenShift)
 && chmod -R g=u "${HOME_TMP}"

# Switch back to root for final configuration
USER root

# Keep the original entrypoint
ENTRYPOINT ["/init"]
