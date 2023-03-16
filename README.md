# Argo on Kubernetes

- [Argo Workflow](https://argoproj.github.io/argo-events/sensors/triggers/argo-workflow/)
- [Argo EventSource Services](https://argoproj.github.io/argo-events/eventsources/services/)
- [Kubernetes Ingress with TLS/SSL](https://github.com/HoussemDellai/kubernetes-ingress-tls-ssl-https)

## Delete namespace

```bash
# Terminal 1
kubectl delete namespaces {TargetNamespace}
kubectl proxy
# Terminal 2
kubectl get ns {TargetNamespace} -o json | jq '.spec.finalizers=[]' | curl -X PUT http://localhost:8001/api/v1/namespaces/{TargetNamespace}/finalize -H "Content-Type: application/json" --data @-
```

## Setup

### Argo server

```bash
kubectl create namespace argo
kubectl apply --namespace argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.5/install.yaml
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server"]}]'
kubectl --namespace argo port-forward deployment/argo-server 2746:2746
```

### Argo events

```bash
kubectl create namespace argo-events
# Setup argo events
kubectl apply --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
# Setup "operate-workflow-sa" service account name
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/master/examples/rbac/sensor-rbac.yaml
# Create event bus
kubectl --namespace argo-events apply --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
```

## Event source

### Apply the event source

```bash
kubectl --namespace argo-events apply --filename event-source.yaml
```

### Check availability

```bash
kubectl --namespace argo-events get eventsources
# kubectl --namespace argo-events delete eventsources {EventSourceName}
kubectl --namespace argo-events get services
# kubectl --namespace argo-events delete services {ServiceName}
kubectl --namespace argo-events get pods
# kubectl --namespace argo-events delete pods {PodName}
```

### Port forward

```bash
kubectl --namespace argo-events port-forward $(kubectl --namespace argo-events get pods --output name --selector eventsource-name={EventSourceName}) 4321:4321
```

## Sensor

### Apply the sensor

```bash
kubectl --namespace argo-events apply --filename {SensorFileName}.yaml
```

### Check availability

```bash
kubectl --namespace argo-events get sensors
# kubectl --namespace argo-events delete sensors {SensorName}
```

## Create event

```bash
curl -X POST -H "Content-Type: application/json" -d '{"message":"Suthinan Musitmani"}' http://localhost:4321/webhook
```

## Check results

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

### Delete ingress class

```bash
kubectl get ingressClasses
kubectl delete ingressClasses nginx
kubectl get validatingwebhookconfigurations 
kubectl delete validatingwebhookconfigurations {ConfigurationName}
helm delete app-ingress --namespace ingress
kubectl delete namespace ingress
```

### Add the Helm chart for Nginx ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-argo-events-ingress ingress-nginx/ingress-nginx \
     --namespace ingress \
     --create-namespace \
     --set controller.replicaCount=2 \
     --set controller.nodeSelector."kubernetes\.io/os"=linux \
     --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux
```

### Check availability

```bash
kubectl get services --namespace ingress
```

### Create argo events ingress

```bash
kubectl apply --filename argo-events-ingress.yaml
kubectl get ingress -A
```
