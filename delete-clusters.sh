#!/bin/bash
for CLUSTER in 1 2; do
  echo ""
  echo " -> Deleting cluster in namespace 'geode-cluster-${CLUSTER}'"	
  helm delete --namespace=geode-cluster-${CLUSTER} geode-kub
  kubectl delete pvc disk-locator-0 --namespace=geode-cluster-${CLUSTER}
done
