#!/bin/bash

for CLUSTER in 1 2; do
  NAMESPACE="geode-cluster-${CLUSTER}"
  kubectl get namespace ${NAMESPACE} &> /dev/null
  if [ $? -ne 0 ]; then
    echo ""	  
    echo " -> Creating namespace '${NAMESPACE}'"
    echo "{ \"apiVersion\": \"v1\", \"kind\": \"Namespace\", \"metadata\": { \"name\": \"${NAMESPACE}\", \"labels\": { \"name\": \"${NAMESPACE}\" } } }" > namespace.json
    kubectl create -f namespace.json
    rm namespace.json
  else
    echo " -> Skipping creation of namespace '${NAMESPACE}' (already exists)"	  
  fi
done

for CLUSTER in 1 2; do
  echo ""
  echo " -> Installing cluster in namespace 'geode-cluster-${CLUSTER}'"  
  helm install --namespace=geode-cluster-${CLUSTER} -f cluster-${CLUSTER}-values.yaml geode-kub charts/geode-kub &
  pids[${i}]=$!
  sleep 1
done

for pid in ${pids[*]}; do
    wait $pid
done
