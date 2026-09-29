# Service Account for Jenkins Kubernetes Agents

Creates a `jenkins` service account that can run agent pods in the `k8s` namespace only (no cluster-wide access), then builds a standalone kubeconfig for it.

Works on any cluster (EKS, AKS, GKE, kubeadm, k3s, minikube, ...). The generated kubeconfig authenticates with a plain SA token, so Jenkins doesn't need `aws` / `az` / `gcloud` CLIs or any auth plugin.

> Run steps 1–3 with an admin kubeconfig pointed at the target cluster (`kubectl config current-context`).

## 1. Apply `sa.yml`

```sh
kubectl apply -f sa.yml
```

| Resource | Name | Purpose |
|---|---|---|
| ServiceAccount | `jenkins` | Identity Jenkins uses |
| RoleBinding | `jenkins-admin` | Full access inside `k8s` (built-in `admin` role) |
| Secret | `jenkins-token` | Long-lived token (K8s 1.24+ doesn't create one automatically) |

## 2. Verify permissions

```sh
kubectl auth can-i create pods -n k8s --as=system:serviceaccount:k8s:jenkins   # yes
kubectl auth can-i list namespaces --as=system:serviceaccount:k8s:jenkins      # no (expected)
```

## 3. Fill in the kubeconfig

[`kube_config.yml`](kube_config.yml) is a template. Replace its three placeholders with the values from these commands:

| Placeholder | Command | Notes |
|---|---|---|
| `<SERVER_URL>` | `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'` | See the cluster table below |
| `<CA_DATA>` | `kubectl get secret jenkins-token -n k8s -o jsonpath='{.data.ca\.crt}'` | Paste as-is (stays base64) |
| `<TOKEN>` | `kubectl describe secret jenkins-token -n k8s` | Copy the `token:` value (already decoded) |

Optionally rename `my-cluster` to something meaningful (e.g. `prod-eks`).

**Test it**

```sh
kubectl --kubeconfig kube_config.yml get pods          # works (uses namespace k8s)
kubectl --kubeconfig kube_config.yml get ns            # Forbidden (expected)
```

> ⚠️ Once filled in, `kube_config.yml` contains a live token. Don't commit it. Only the placeholder version belongs in git.

### Check the `server:` URL for your cluster type

The URL must be reachable **from Jenkins**, not just from your machine.

| Cluster | What to check |
|---|---|
| **EKS / AKS / GKE** | URL from the current context is fine. If the API endpoint is private, Jenkins must be in the same VPC/VNet or have network access to it. |
| **kubeadm / k3s / on-prem** | Replace `127.0.0.1` or `localhost` with the control-plane IP / DNS / load balancer. The name must match a SAN in the API server cert. |
| **Rancher-managed** | Use the cluster's direct API endpoint, not the Rancher proxy URL (`https://rancher/k8s/clusters/...`), which needs a Rancher token. |
| **minikube** | `127.0.0.1:<port>` only works on the host. From a Jenkins container, use `https://$(minikube ip):8443` (or put Jenkins on the minikube Docker network). |
| **Docker Desktop / kind** | From a Jenkins container, use `https://host.docker.internal:<port>` or `https://<kind-control-plane>:6443` on the `kind` network. |

## 4. Configure Jenkins

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
