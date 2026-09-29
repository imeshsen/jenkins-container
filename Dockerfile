FROM jenkins/jenkins:lts

USER root

# Docker group with host GID
RUN groupadd -g 984 docker || true
RUN usermod -aG docker jenkins

RUN usermod -aG 0 jenkins

USER jenkins
