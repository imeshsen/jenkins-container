# Service Account for Jenkins Kubernetes Agents

Creates a `jenkins` service account that can run agent pods in the `k8s` namespace only (no cluster-wide access).

## 1. Create the namespace (if it doesn't exist)

```sh
kubectl create namespace k8s
```

## 2. Apply `sa.yml`

```sh
kubectl apply -f sa.yml
```

This creates:

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

## 4. Get the token and CA cert

```sh
kubectl get secret jenkins-token -n k8s -o jsonpath='{.data.token}' | base64 -d
kubectl get secret jenkins-token -n k8s -o jsonpath='{.data.ca\.crt}' | base64 -d
```

## 5. Configure Jenkins

1. **Manage Jenkins → Credentials** → add a **Secret text** credential with the token.
2. **Manage Jenkins → Clouds → New cloud → Kubernetes**:
   - **Kubernetes URL**: your API server URL (`kubectl cluster-info`)
   - **Kubernetes server certificate key**: the CA cert from step 4
   - **Kubernetes Namespace**: `k8s` ← required, the SA can't see other namespaces
   - **Credentials**: the token credential
3. Click **Test Connection**.

## Troubleshooting

`namespaces is forbidden: ... cannot list resource "namespaces"` means the namespace field is empty in Jenkins, or `kubectl` is running without `-n k8s`. Set the namespace; don't grant cluster access.
