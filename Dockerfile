# Use the Kubeflow Code-Server Python image
FROM kubeflownotebookswg/codeserver-python:latest

# Switch to root to make modifications
USER root


EXPOSE 8888

# Keep the original entrypoint
ENTRYPOINT ["/init"]
