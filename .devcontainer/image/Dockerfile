# Dev container image: i2's ADT dev image with the Azure tools already installed, so opening
# the container downloads nothing else. Built and published by
# .github/workflows/devcontainer-image.yml to ghcr.io/<owner>/i2-devcontainer.
ARG ADT_DEV_IMAGE=i2group/i2eng-analyze-containers-dev:1.2
FROM ${ADT_DEV_IMAGE}

ARG AZURE_CLI_VERSION=2.90.0
ARG BICEP_VERSION=v0.47.16
ARG KUBECTL_VERSION=v1.37.0
ARG KUBELOGIN_VERSION=v0.2.19

USER root

# az in a venv (the azure-cli RPM pulls deps that are not in the UBI repos)
RUN python3.12 -m venv /opt/azure-cli \
 && /opt/azure-cli/bin/pip install --no-cache-dir -q --upgrade pip \
 && /opt/azure-cli/bin/pip install --no-cache-dir -q "azure-cli==${AZURE_CLI_VERSION}" \
 && ln -s /opt/azure-cli/bin/az /usr/local/bin/az

# Bicep, kubectl and kubelogin on the PATH. ~/.azure is a volume, so az must use the
# bicep on the PATH rather than installing its own copy there.
RUN curl -fsSL -o /usr/local/bin/bicep \
      "https://github.com/Azure/bicep/releases/download/${BICEP_VERSION}/bicep-linux-x64" \
 && chmod +x /usr/local/bin/bicep \
 && curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl \
 && curl -fsSL -o /tmp/kubelogin.zip \
      "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip" \
 && python3.12 -m zipfile -e /tmp/kubelogin.zip /tmp/kubelogin \
 && install -m 0755 /tmp/kubelogin/bin/linux_amd64/kubelogin /usr/local/bin/kubelogin \
 && rm -rf /tmp/kubelogin /tmp/kubelogin.zip
ENV AZURE_BICEP_USE_BINARY_FROM_PATH=true \
    AZURE_BICEP_CHECK_VERSION=false

# ~/.azure is mounted as a named volume; pre-create it so the volume is owned by vscode
RUN mkdir -p /home/vscode/.azure && chown vscode:vscode /home/vscode/.azure

LABEL org.opencontainers.image.description="i2 Analyze on Azure dev container: ADT dev image + az, Bicep, kubectl, kubelogin"
