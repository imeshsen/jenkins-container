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

[`kube_config.yml`](kube_config.yml) is a template. Fill it into `jenkins-kubeconfig.yml` (git-ignored) using either option below.

### Option A: script

Uses your current `kubectl` context:

```sh
./generate-kubeconfig.sh
```

### Option B: manually

Copy `kube_config.yml` to `jenkins-kubeconfig.yml` and replace the three placeholders:

| Placeholder | Command | Notes |
|---|---|---|
| `<SERVER_URL>` | `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'` | Must be reachable from Jenkins |
| `<CA_DATA>` | `kubectl get secret jenkins-token -n k8s -o jsonpath='{.data.ca\.crt}'` | Paste as-is (stays base64) |
| `<TOKEN>` | `kubectl describe secret jenkins-token -n k8s` | Copy the `token:` value (already decoded) |

> **Pasting long values:** `<CA_DATA>` and `<TOKEN>` are each one long line. Keep them on a single line with no breaks or spaces. To avoid terminal line-wrapping, save to a file and copy from an editor:
> ```sh
> kubectl get secret jenkins-token -n k8s -o jsonpath='{.data.ca\.crt}' > ca.txt
> ```
> Don't decode `<CA_DATA>`. The kubeconfig expects base64.

Optionally rename `my-cluster` to something meaningful (e.g. `prod-eks`).

**Test it**

```sh
kubectl --kubeconfig jenkins-kubeconfig.yml get pods   # works (uses namespace k8s)
kubectl --kubeconfig jenkins-kubeconfig.yml get ns     # Forbidden (expected)
```

> ⚠️ `jenkins-kubeconfig.yml` contains a live token. It's git-ignored, so keep it that way. Only the placeholder template `kube_config.yml` belongs in git.

## 4. Configure Jenkins

1. **Manage Jenkins → Credentials** → add a **Secret file** credential and upload `jenkins-kubeconfig.yml`
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
| `connection refused` / timeout | `server:` isn't reachable from Jenkins. Use an address Jenkins can reach, not `127.0.0.1`. |
| `Unauthorized` | Token is empty or the secret was recreated. Regenerate the kubeconfig. |
