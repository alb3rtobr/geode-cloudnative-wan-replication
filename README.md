
Create namespaces for both clusters (`helm`cannot create namespaces so they have to be created in advance):
```
$ kubectl create -f namespaces.json
```

Deploy clusters (one locator + two servers + parallel gw sender + gw receivers):
```
$ helm install --namespace=geode-cluster-1 -f cluster-1-values.yaml geode-kub charts/geode-kub
$ helm install --namespace=geode-cluster-2 -f cluster-2-values.yaml geode-kub charts/geode-kub
```

Check status:
```
$ helm list --namespace=geode-cluster-1
$ kubectl get all --namespace=geode-cluster-1
```

Uninstall:
```
$ helm delete --namespace=geode-cluster-1 geode-kub
$ helm delete --namespace=geode-cluster-2 geode-kub
$ kubectl delete namespace geode-cluster-1 geode-cluster-2
```
