
Create namespaces for both clusters (`helm`cannot create namespaces so they have to be created in advance):
```
$ kubectl create -f namespaces.json 
```

Deploy cluster:
```
$ helm install --namespace=geode-cluster-1 geode-kub charts/geode-kub --set geode_cluster_id=1
$ helm install --namespace=geode-cluster-2 geode-kub charts/geode-kub --set geode_cluster_id=2
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
