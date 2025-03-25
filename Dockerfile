FROM kubeflownotebookswg/codeserver-python:v1.7.0-rc.0

USER root

# Install Node.js, npm, and other tools you need
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    # other packages...
    
# Copy your custom scripts or files
COPY 02-conda-init /etc/cont-init.d/

USER $NB_UID
