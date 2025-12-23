# Jenkins Docker Image – Setup Guide

This guide explains how to build and run a Jenkins Docker image with access to the host Docker daemon.

---

## Steps for creating Jenkins image

### 1. Create Jenkins home directory
Create a directory called `jenkins_home` to persist Jenkins data.

```bash
mkdir jenkins_home
```

---

### 2. Get Docker socket Group ID (on host)
Run the following command on your host machine:

```bash
ls -l /var/run/docker.sock
```

**Example output:**
```
srw-rw---- 1 root docker 0 Dec 23 09:24 /var/run/docker.sock
```

Note the **group ID** from the output.

---

### 3. Modify Dockerfile with the Group ID
Update your Dockerfile using the group ID obtained above.

**Example:**
```dockerfile
RUN usermod -aG 0 jenkins
```

> `0` is the group ID from the Docker socket. Replace it with your actual group ID if different.

---

### 4. Build the Jenkins image

```bash
docker compose build
```

---

### 5. Fix Jenkins home permissions (on host)
Jenkins runs as UID `1000` inside the container.

```bash
sudo chown -R 1000:1000 jenkins_home
sudo chmod -R 775 jenkins_home
```

---

### 6. Start Jenkins

```bash
docker compose up -d
```

---

## Notes
- Docker socket access is controlled by **GID**, not by group name.
- The group ID inside the container **must match** the Docker socket group ID on the host.
- Rebuild the image if the group ID changes.

