# Argo CD Installation

## Argo CD

```bash
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## Ingress

```bash
helm install main-nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.ingressClassResource.name=main-nginx-ingress

kubectl patch deployment argocd-server --namespace argocd --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/1", "value": "--insecure"}]'

kubectl apply -f argocd-ingress.yaml
```

## Sync

```bash
kubectl apply -f argocd-project-sync.yaml
```

## Credentials

- Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

- Add new user

```bash
kubectl get configmap argocd-cm -n argocd -o yaml > argocd-cm.yml && vi argocd-cm.yml
###
apiVersion: v1
data:
  accounts.{NEW_USERNAME}: apiKey, login
...
###
kubectl apply -f argocd-cm.yml
argocd account update-password --account {NEW_USERNAME} --new-password {NEW_PASSWORD}
```

- List accounts

```bash
argocd account list
```

- Update the RBAC

```bash
kubectl get configmap argocd-rbac-cm -n argocd -o yaml > argocd-rbac-cm.yml && vi argocd-rbac-cm.yml
###
apiVersion: v1
data:
  policy.csv: |
    p, role:devops, applications, *, *, allow
    p, role:developers, applications, *, *, allow
    p, role:devops, clusters, get, *, allow
    p, role:devops, repositories, get, *, allow
    p, role:devops, repositories, create, *, allow
    p, role:devops, repositories, update, *, allow
    p, role:devops, repositories, delete, *, allow
    p, role:devops, gpgkeys, get, *, allow
    g, {NEW_USERNAME}, role:admin
...
###
kubectl apply -f argocd-rbac-cm.yml
```

- Disable admin

```bash
kubectl get configmap argocd-cm -n argocd -o yaml > argocd-cm.yml && vi argocd-cm.yml
###
apiVersion: v1
data:
  ...
  admin.enabled: "false"
...
###
kubectl apply -f argocd-cm.yml
```

## Argo CD CLI

- [Installation](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

```bash
argocd login {ARGOCD_FQDN} --username admin --password {ARGO_PASSWORD} --skip-test-tls --grpc-web
```

## Image pull secret

```bash
kubectl create secret docker-registry my-registry-secret --docker-server="docker.io" \
  --docker-username="{DOCKER_USERNAME}" \
  --docker-password="{DOCKER_PASSWORD}" \
  --docker-email="docker@email.com" \
  --namespace=argocd
```
