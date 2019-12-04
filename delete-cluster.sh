#!/bin/bash
helm delete --namespace=geode-cluster-$1 geode-kub
kubectl delete pvc disk-locator-0 --namespace=geode-cluster-$1
