FROM jenkins/jenkins:lts

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add Docker GPG key (NON-INTERACTIVE FIX)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repo (force bullseye)
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  bullseye stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CLI only
RUN apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Docker group with host GID
RUN groupadd -g 984 docker || true
RUN usermod -aG docker jenkins

RUN usermod -aG 0 jenkins

USER jenkins
