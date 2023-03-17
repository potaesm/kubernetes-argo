# Argo on Kubernetes

- [Argo Workflow](https://argoproj.github.io/argo-events/sensors/triggers/argo-workflow/)
- [Argo EventSource Services](https://argoproj.github.io/argo-events/eventsources/services/)
- [Kubernetes Ingress with TLS/SSL](https://github.com/HoussemDellai/kubernetes-ingress-tls-ssl-https)
- [SSL/TLS for your Kubernetes Cluster with Cert-Manager](https://towardsdatascience.com/ssl-tls-for-your-kubernetes-cluster-with-cert-manager-3db24338f17)

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

```bash
kubectl create namespace argo
kubectl apply --namespace argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.5/install.yaml
# kubectl delete --namespace argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.5/install.yaml
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server"]}]'
kubectl patch deployment argo-server --namespace argo --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env", "value": [{"name": "BASE_HREF", "value": "/argo/"}]}]'
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

### Make a request to webhook

```bash
curl -X POST -H "Content-Type: application/json" -d '{"message":"Suthinan Musitmani"}' http://localhost:4321/webhook
```

### Check results

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

#### Delete the existing ingress class

```bash
kubectl get validatingwebhookconfigurations
kubectl delete validatingwebhookconfigurations {ConfigurationName}
helm delete my-nginx-ingress --namespace ingress
kubectl get ingressClasses
kubectl delete ingressClasses nginx
kubectl delete namespace ingress
```

#### Install the Nginx ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install my-nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
# kubectl patch deployment my-nginx-ingress-ingress-nginx-controller \
#     --namespace ingress \
#     --type='json' \
#     --patch '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--default-ssl-certificate=argo-events/my-tls-secret"}]'
# kubectl edit deployment.apps my-nginx-ingress-ingress-nginx-controller --namespace ingress
```

#### Check ingress availability

```bash
kubectl get services --namespace ingress
kubectl --namespace ingress get services -o wide -w my-nginx-ingress-ingress-nginx-controller
```

#### Generate TLS certificate

```bash
kubectl create ns cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.11.0/cert-manager.yaml
kubectl apply -f letsencrypt.yaml --namespace cert-manager
kubectl get secrets -n cert-manager
```

#### Create argo events ingress

```bash
kubectl apply --filename argo-server-ingress.yaml
kubectl apply --filename argo-events-ingress.yaml
kubectl get ingress -A
```
