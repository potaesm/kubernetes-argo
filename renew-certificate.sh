#!/bin/bash

NAME_SPACE=argo

# Delete the Certificate and its accompanying Secret
# CERT_NAME=$(kubectl get certificates -n $NAME_SPACE -o name | cut -d'/' -f 2)
CERT_NAME=le-cert
ORIGINAL_CERT_EXPIRY=$(kubectl get certificate -n $NAME_SPACE -o=jsonpath='{.items[0].status.notAfter}')
echo "Certificate expires on $ORIGINAL_CERT_EXPIRY"

# Use date -d if you're using non-BSD/MacOS
ORIGINAL_CERT_EXPIRY_DATE=$(date -j -f "%F" $ORIGINAL_CERT_EXPIRY +"%s")

kubectl delete certificate $CERT_NAME -n $NAME_SPACE

# NAME_SPACE_CERTS_SECRET=$(kubectl get secrets -n $NAME_SPACE -o=jsonpath='{.items[1].metadata.name}')
NAME_SPACE_CERTS_SECRET=le-cluster-issuer-key
kubectl delete secret $NAME_SPACE_CERTS_SECRET -n $NAME_SPACE

# Just for kicks
CERT_MANAGER_POD_NAME=$(kubectl get pods -n cert-manager -o=jsonpath='{.items[0].metadata.name}')
echo Pod name: $CERT_MANAGER_POD_NAME

# Apply new certificate
kubectl apply -f letsencrypt.yaml -n $NAME_SPACE

# May take a bit of time for the certificate to generate. Putting in a pause.
echo "Sleeping for 40 seconds to give the certificate time to generate"
sleep 40

# Get our new certificat's expiry date
# kubectl describe certificates $CERT_NAME -n $NAME_SPACE
NEW_CERT_EXPIRY=$(kubectl get certificate -n $NAME_SPACE -o=jsonpath='{.items[0].status.notAfter}')
echo "New Certificate expires on $NEW_CERT_EXPIRY"
# Use date -d if you're using non-BSD/MacOS
NEW_CERT_EXPIRY_DATE=$(date -j -f "%F" $NEW_CERT_EXPIRY +"%s")

# We want to make sure that the new certificate's expiry date is after our old certificate's expiry date
if [ $NEW_CERT_EXPIRY_DATE -ge $ORIGINAL_CERT_EXPIRY_DATE ];
then
    echo "Success! New certificate generated. New expiry date is $NEW_CERT_EXPIRY"
else
    echo "***ERROR!! Expiry date not updated. Old expiry date: $ORIGINAL_CERT_EXPIRY. New expiry date: $NEW_CERT_EXPIRY"
    exit 1
fi

# Let's make sure that the secret accompanying our certificate was also created
SECRET_CERT_NAME=tls-cert-secret
SECERT_NAME=$(kubectl get secrets -n $NAME_SPACE $SECRET_CERT_NAME -o name)
if [ "$SECERT_NAME" == "secret/$SECRET_CERT_NAME" ];
then
    echo "Secret $SECRET_NAME created."
else
    echo "Missing secret"
    exit 1
fi

# https://medium.com/dzerolabs/how-to-renew-lets-encrypt-certificates-managed-by-cert-manager-on-kubernetes-2a74f9a0975d