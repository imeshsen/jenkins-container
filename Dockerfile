# Dockerfile
FROM jenkins/jenkins:lts

USER root

# Install dependencies for Docker CLI
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    rm -rf /var/lib/apt/lists/*

# Add Docker's official GPG key
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add the Docker repository to Apt sources
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt index and install Docker CLI
RUN apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# --- FIX: Create the 'docker' group with the host's Docker GID (984) ---
# Removed ARG and hardcoded for simplicity, as we know the GID now.
RUN groupadd -g 984 docker || true

# Add the jenkins user to the docker group
RUN usermod -aG docker jenkins

USER jenkins
