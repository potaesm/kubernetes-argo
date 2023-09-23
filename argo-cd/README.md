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

vi argocd-ingress.yaml

###
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /argocd(/|$)(.*)
            pathType: ImplementationSpecific # Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
---
###
```

## Credentials

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
# kubectl get svc argocd-server -n argocd -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname'
```

## Argo CD CLI

- [Installation](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

```bash
argocd login {ARGOCD_FQDN} --username admin --password {ARGO_PASSWORD} --skip-test-tls --grpc-web
```
