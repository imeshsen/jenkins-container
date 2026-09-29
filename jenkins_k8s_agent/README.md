# Service Account for Jenkins Kubernetes Agents

Creates a `jenkins` service account that can run agent pods in the `k8s` namespace only (no cluster-wide access), then builds a standalone kubeconfig for it.

Works on any cluster (EKS, AKS, GKE, kubeadm, k3s, minikube, ...). The generated kubeconfig authenticates with a plain SA token, so Jenkins doesn't need `aws` / `az` / `gcloud` CLIs or any auth plugin.

> Run steps 1–4 with an admin kubeconfig pointed at the target cluster (`kubectl config current-context`).

## 1. Create the namespace (if it doesn't exist)

```sh
kubectl create namespace k8s
```

## 2. Apply `sa.yml`

```sh
kubectl apply -f sa.yml
```

| Resource | Name | Purpose |
|---|---|---|
| ServiceAccount | `jenkins` | Identity Jenkins uses |
| RoleBinding | `jenkins-admin` | Full access inside `k8s` (built-in `admin` role) |
| Secret | `jenkins-token` | Long-lived token (K8s 1.24+ doesn't create one automatically) |

## 3. Verify permissions

```sh
kubectl auth can-i create pods -n k8s --as=system:serviceaccount:k8s:jenkins   # yes
kubectl auth can-i list namespaces --as=system:serviceaccount:k8s:jenkins      # no (expected)
```

## 4. Generate the kubeconfig

Pulls the API server URL from your current context and the token + CA cert from the `jenkins-token` secret.

**Bash (Linux / macOS / Git Bash)**

```sh
NS=k8s
SA=jenkins
SECRET=jenkins-token

CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl get secret $SECRET -n $NS -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl get secret $SECRET -n $NS -o jsonpath='{.data.token}' | base64 -d)

cat > kube_config.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER
  cluster:
    server: $SERVER
    certificate-authority-data: $CA
users:
- name: $SA
  user:
    token: $TOKEN
contexts:
- name: $SA@$CLUSTER
  context:
    cluster: $CLUSTER
    user: $SA
    namespace: $NS
current-context: $SA@$CLUSTER
EOF
```

**PowerShell (Windows)**

```powershell
$NS = "k8s"; $SA = "jenkins"; $SECRET = "jenkins-token"

$CLUSTER = kubectl config view --minify -o jsonpath='{.clusters[0].name}'
$SERVER  = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
$CA      = kubectl get secret $SECRET -n $NS -o jsonpath='{.data.ca\.crt}'
$TOKEN   = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(
             (kubectl get secret $SECRET -n $NS -o jsonpath='{.data.token}')))

@"
apiVersion: v1
kind: Config
clusters:
- name: $CLUSTER
  cluster:
    server: $SERVER
    certificate-authority-data: $CA
users:
- name: $SA
  user:
    token: $TOKEN
contexts:
- name: $SA@$CLUSTER
  context:
    cluster: $CLUSTER
    user: $SA
    namespace: $NS
current-context: $SA@$CLUSTER
"@ | Set-Content -Encoding ascii kube_config.yml
```

**Test it**

```sh
kubectl --kubeconfig kube_config.yml get pods          # works (uses namespace k8s)
kubectl --kubeconfig kube_config.yml get ns            # Forbidden (expected)
```

> ⚠️ `kube_config.yml` contains a live token. Don't commit it. Add it to `.gitignore`.

### Check the `server:` URL for your cluster type

The URL must be reachable **from Jenkins**, not just from your machine.

| Cluster | What to check |
|---|---|
| **EKS / AKS / GKE** | URL from the current context is fine. If the API endpoint is private, Jenkins must be in the same VPC/VNet or have network access to it. |
| **kubeadm / k3s / on-prem** | Replace `127.0.0.1` or `localhost` with the control-plane IP / DNS / load balancer. The name must match a SAN in the API server cert. |
| **Rancher-managed** | Use the cluster's direct API endpoint, not the Rancher proxy URL (`https://rancher/k8s/clusters/...`), which needs a Rancher token. |
| **minikube** | `127.0.0.1:<port>` only works on the host. From a Jenkins container, use `https://$(minikube ip):8443` (or put Jenkins on the minikube Docker network). |
| **Docker Desktop / kind** | From a Jenkins container, use `https://host.docker.internal:<port>` or `https://<kind-control-plane>:6443` on the `kind` network. |

## 5. Configure Jenkins

1. **Manage Jenkins → Credentials** → add a **Secret file** credential and upload `kube_config.yml`
   (or a **Secret text** credential with just the token).
2. **Manage Jenkins → Clouds → New cloud → Kubernetes**:
   - **Credentials**: the kubeconfig credential (URL and CA come from the file).
     If you used Secret text, also fill in **Kubernetes URL** and **Kubernetes server certificate key**.
   - **Kubernetes Namespace**: `k8s` (required, because the SA can't see other namespaces)
3. Click **Test Connection**.

## Troubleshooting

| Error | Fix |
|---|---|
| `namespaces is forbidden ... cannot list resource "namespaces"` | Set the namespace to `k8s` in Jenkins or use `-n k8s`. Don't grant cluster access. |
| `x509: certificate signed by unknown authority` | Wrong/missing CA. Regenerate the kubeconfig from the right cluster context. |
| `x509: certificate is valid for ..., not <host>` | `server:` hostname isn't in the API cert. Use a name/IP the cert covers. |
| `connection refused` / timeout | `server:` isn't reachable from Jenkins. See the cluster table above. |
| `Unauthorized` | Token is empty or the secret was recreated. Regenerate the kubeconfig. |
