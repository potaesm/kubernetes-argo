# Argo on Kubernetes

## Useful links

- [Argo Workflow](https://argoproj.github.io/argo-events/sensors/triggers/argo-workflow/)
- [Argo EventSource Services](https://argoproj.github.io/argo-events/eventsources/services/)
- [Argo Parameterization](https://argoproj.github.io/argo-events/tutorials/02-parameterization/)
- [Kubernetes Ingress with TLS/SSL](https://github.com/HoussemDellai/kubernetes-ingress-tls-ssl-https)
- [SSL/TLS for your Kubernetes Cluster with Cert-Manager](https://towardsdatascience.com/ssl-tls-for-your-kubernetes-cluster-with-cert-manager-3db24338f17)

## Contents

- [Force delete namespace](#force-delete-namespace)
- [Argo](#argo)
  - [Setup the Argo server](#setup-the-argo-server)
    - [Argo server installation](#argo-server-installation)
    - [Argo server port forward](#argo-server-port-forward)
  - [Setup the Argo events](#setup-the-argo-events)
    - [Setup the "operate-workflow-sa" service account name](#setup-the-operate-workflow-sa-service-account-name)
    - [Setup the event bus](#setup-the-event-bus)
    - [Apply the event source](#apply-the-event-source)
    - [Check argo events availability](#check-argo-events-availability)
    - [Argo events port forward](#argo-events-port-forward)
  - [Sensors](#sensors)
    - [Apply the sensor](#apply-the-sensor)
    - [Check sensors availability](#check-sensors-availability)
  - [Create events](#create-events)
    - [Make a request to webhook](#make-a-request-to-webhook)
    - [Check event results](#check-event-results)
- [Kill the network](#kill-the-network)
- [Ingress](#ingress)
  - [Delete the existing ingress class](#delete-the-existing-ingress-class)
  - [Install the Nginx ingress](#install-the-nginx-ingress)
  - [Check ingress availability](#check-ingress-availability)
  - [Manually insert TLS certificates](#manually-insert-tls-certificates)
  - [Generate TLS certificates](#generate-tls-certificates)
  - [(Optional) Force Nginx ingress to use the generated certificate path](#optional-force-nginx-ingress-to-use-the-generated-certificate-path)
  - [Create argo events ingress](#create-argo-events-ingress)
  - [Enable whitelist source range](#enable-whitelist-source-range)
- [Authentication](#authentication)
  - [Argo server authentication](#argo-server-authentication)
    - [Change auth mode](#change-auth-mode)
    - [Service account role binding](#service-account-role-binding)
  - [Webhook authentication](#webhook-authentication)
    - [Create the token secret](#create-the-token-secret)
    - [Apply the auth secret](#apply-the-auth-secret)
- [Using private container registry](#using-private-container-registry)
  - [Attach Azure Container Registry to the AKS cluster](#attach-azure-container-registry-to-the-aks-cluster)
  - [Create registry secret](#create-registry-secret)

## Force delete namespace

```bash
# Terminal 1
kubectl delete namespaces {TargetNamespace}
kubectl proxy
# Terminal 2
kubectl get ns {TargetNamespace} -o json | jq '.spec.finalizers=[]' | curl -X PUT http://localhost:8001/api/v1/namespaces/{TargetNamespace}/finalize -H "Content-Type: application/json" --data @-
```

## Argo

### Setup the Argo server

#### Argo server installation

```bash
kubectl create namespace argo
kubectl apply --namespace argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.5/install.yaml
# kubectl delete --namespace argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.5/install.yaml
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server"]}]'
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "BASE_HREF", "value": "/argo/"}]}]'
```

#### Argo server port forward

```bash
kubectl --namespace argo port-forward deployment/argo-server 2746:2746
```

### Setup the Argo events

```bash
kubectl create namespace argo-events
# Setup argo events
kubectl apply --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
# kubectl delete --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

#### Setup the "operate-workflow-sa" service account name

```bash
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/master/examples/rbac/sensor-rbac.yaml
```

#### Setup the event bus

```bash
kubectl --namespace argo-events apply --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
```

#### Apply the event source

```bash
kubectl --namespace argo-events apply --filename event-source.yaml
```

#### Check argo events availability

```bash
kubectl --namespace argo-events get eventsources
# kubectl --namespace argo-events delete eventsources {EventSourceName}
kubectl --namespace argo-events get services
# kubectl --namespace argo-events delete services {ServiceName}
kubectl --namespace argo-events get pods
# kubectl --namespace argo-events delete pods {PodName}
```

#### Argo events port forward

```bash
kubectl --namespace argo-events port-forward $(kubectl --namespace argo-events get pods --output name --selector eventsource-name={EventSourceName}) 4321:4321
```

### Sensors

#### Apply the sensor

```bash
kubectl --namespace argo-events apply --filename {SensorFileName}.yaml
```

#### Check sensors availability

```bash
kubectl --namespace argo-events get sensors
# kubectl --namespace argo-events delete sensors {SensorName}
```

### Create events

#### Make a request to webhook

```bash
curl -X POST -H "Content-Type: application/json" -d '{"message":"Suthinan Musitmani"}' http://localhost:4321/webhook
```

#### Check event results

```bash
kubectl --namespace argo-events get pods
kubectl --namespace argo-events logs {PodName}
# kubectl --namespace argo-events delete pods {PodName}
```

## Kill the network

```bash
pkill kubectl -9
```

## Ingress

### Delete the existing ingress class

```bash
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations {ConfigurationName}
helm delete my-nginx-ingress --namespace ingress
kubectl get ingressClasses
kubectl delete ingressClasses nginx
kubectl delete namespace ingress
```

### Install the Nginx ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.ingressClassResource.name=my-nginx-ingress
```

### Check ingress availability

```bash
kubectl get services --namespace ingress
kubectl --namespace ingress get services -o wide -w my-nginx-ingress-ingress-nginx-controller
# Prepare DNS record with the nginx ingress external IP
```

### Manually insert TLS certificates

```bash
kubectl create secret tls tls-cert-secret \
--namespace {OneOfTargetIngressNamespace} \
--key privkey.pem \
--cert cert.pem
```

### Generate TLS certificates

```bash
# https://ikarus.sg/deploy-cert-manager-tls/
kubectl create namespace cert-manager
kubectl apply --filename https://github.com/jetstack/cert-manager/releases/download/v1.11.0/cert-manager.yaml
kubectl apply --filename letsencrypt.yaml --namespace {OneOfTargetIngressNamespace}
kubectl get secrets --namespace {TargetIngressNamespace}
kubectl describe certificate.cert-manager.io/le-cert -n {TargetIngressNamespace}
kubectl describe secrets tls-cert-secret --namespace {TargetIngressNamespace}
kubectl --namespace {TargetIngressNamespace} get secret tls-cert-secret -ojson | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -dates -noout -issuer
```

### (Optional) Force Nginx ingress to use the generated certificate path

```bash
kubectl patch deployment my-nginx-ingress-ingress-nginx-controller \
    --namespace ingress \
    --type='json' \
    --patch '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--default-ssl-certificate={TargetIngressNamespace}/tls-cert-secret"}]'
# kubectl edit deployment.apps my-nginx-ingress-ingress-nginx-controller --namespace ingress
```

### Create argo events ingress

```bash
kubectl apply --filename argo-server-ingress.yaml
kubectl apply --filename argo-events-ingress.yaml
kubectl get ingress -A
```

### Enable whitelist source range

```bash
kubectl patch svc my-nginx-ingress-ingress-nginx-controller -p '{"spec":{"externalTrafficPolicy":"Local"}}' --namespace ingress
# Define whitelist source at nginx.ingress.kubernetes.io/whitelist-source-range
kubectl apply --filename argo-events-ingress.yaml
```

## Authentication

### Argo server authentication

#### Change auth mode

```bash
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=client"]}]'
```

#### Service account role binding

```bash
kubectl apply --filename role-binding.yaml
kubectl apply --filename argo-server-token.yaml --namespace argo
echo "Bearer $(kubectl get secret argo-server.service-account-token --namespace argo -o=jsonpath='{.data.token}' | base64 --decode)"
```

### Webhook authentication

#### Create the token secret

```bash
echo -n "$(kubectl get secret argo-server.service-account-token -n argo -o=jsonpath='{.data.token}' | base64 --decode)" > ./webhook-token.txt
kubectl --namespace argo-events create secret generic my-webhook-token --from-file=my-token=./webhook-token.txt
```

#### Apply the auth secret

```bash
# Enable authSecret at the webhook event source
kubectl --namespace argo-events apply --filename event-source.yaml
```

## Using private container registry

### Attach Azure Container Registry to the AKS cluster

```bash
az aks update -n {AKSClusterName} -g {ResourceGroupName} --attach-acr {ACRName}
# Check ACR availability
az aks check-acr --resource-group {ResourceGroupName} --name {AKSClusterName} --acr {ACRName}.azurecr.io
```

### Create registry secret

```bash
kubectl create secret docker-registry my-registry-secret --docker-server="{ACRName}.azurecr.io" \
--docker-username="{ACRUsername}" \
--docker-password="{ACRPassword}" \
--docker-email="{DockerEmail}" \
--namespace=argo-events
# Add secret reader role binding
kubectl apply --filename role-binding.yaml
# Add imagePullSecrets to the sensor
kubectl --namespace argo-events apply --filename {SensorFileName}.yaml
```
