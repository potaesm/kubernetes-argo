# Argo on Kubernetes

## Setup
```bash
kubectl create namespace argo-events
kubectl apply --filename https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
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
# kubectl --namespace argo-events delete eventsources <EventSourceName>
kubectl --namespace argo-events get services
# kubectl --namespace argo-events delete services <ServiceName>
kubectl --namespace argo-events get pods
# kubectl --namespace argo-events delete pods <PodName>
```
### Port forward
```bash
kubectl --namespace argo-events port-forward $(kubectl --namespace argo-events get pods --output name --selector eventsource-name=<EventSourceName>) 4321:4321
```

## Sensor
### Apply the sensor
```bash
kubectl --namespace argo-events apply --filename sensor.yaml
```
### Check availability
```bash
kubectl --namespace argo-events get sensors
# kubectl --namespace argo-events delete sensors <SensorName>
```

## Create event
```bash
curl -X POST -H "Content-Type: application/json" -d '{"message":"Suthinan Musitmani"}' http://localhost:4321/webhook
```

## Check results
```bash
kubectl --namespace argo-events get pods --selector app=print-payload-app
kubectl --namespace argo-events logs --selector app=print-payload-app
# kubectl --namespace argo-events delete pods --selector app=print-payload-app
```

## Kill the network
```bash
pkill kubectl -9
```