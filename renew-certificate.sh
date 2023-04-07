#!/bin/bash

NAME_SPACE=argo
CERT_NAME=le-cert
SECRET_CERT_NAME=tls-cert-secret
NAME_SPACE_CERTS_SECRET=le-cluster-issuer-key

ORIGINAL_CERT_EXPIRY=$(kubectl get certificate -n $NAME_SPACE -o=jsonpath='{.items[0].status.notAfter}')
echo "Certificate expires on $ORIGINAL_CERT_EXPIRY"
ORIGINAL_CERT_EXPIRY_DATE=$(date -j -f "%F" $ORIGINAL_CERT_EXPIRY +"%s")

kubectl delete certificate $CERT_NAME -n $NAME_SPACE
kubectl delete secret $SECRET_CERT_NAME -n $NAME_SPACE
kubectl delete secret $NAME_SPACE_CERTS_SECRET -n $NAME_SPACE

CERT_MANAGER_POD_NAME=$(kubectl get pods -n cert-manager -o=jsonpath='{.items[0].metadata.name}')
echo Pod name: $CERT_MANAGER_POD_NAME

kubectl apply -f letsencrypt.yaml -n $NAME_SPACE

echo "Sleeping for 40 seconds to give the certificate time to generate"
sleep 40

NEW_CERT_EXPIRY=$(kubectl get certificate -n $NAME_SPACE -o=jsonpath='{.items[0].status.notAfter}')
echo "New Certificate expires on $NEW_CERT_EXPIRY"
NEW_CERT_EXPIRY_DATE=$(date -j -f "%F" $NEW_CERT_EXPIRY +"%s")

if [ $NEW_CERT_EXPIRY_DATE -ge $ORIGINAL_CERT_EXPIRY_DATE ];
then
    echo "Success! New certificate generated. New expiry date is $NEW_CERT_EXPIRY"
else
    echo "***ERROR!! Expiry date not updated. Old expiry date: $ORIGINAL_CERT_EXPIRY. New expiry date: $NEW_CERT_EXPIRY"
    exit 1
fi

SECERT_NAME=$(kubectl get secrets -n $NAME_SPACE $SECRET_CERT_NAME -o name)
if [ "$SECERT_NAME" == "secret/$SECRET_CERT_NAME" ];
then
    echo "Secret $SECRET_NAME created."
else
    echo "Missing secret"
    exit 1
fi

# https://medium.com/dzerolabs/how-to-renew-lets-encrypt-certificates-managed-by-cert-manager-on-kubernetes-2a74f9a0975d