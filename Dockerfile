FROM kubeflownotebookswg/codeserver-python:v1.7.0-rc.0

USER root

# Install Node.js, npm, and other tools you need
RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    # other packages...
    
