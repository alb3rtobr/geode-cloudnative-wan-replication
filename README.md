
This repo can be used to reproduce an issue in Geode WAN replication when using a cloud-native environment (Kubernetes in this case).

If several receivers are exposed using the same `hostname-for-senders` parameter, they are treated as if they were just one. So when one of them is not available, connections to that receivers are not moved to the other available receiver.


# Setup the environment

The environment consists on two Geode clusters in different namespaces, composed by one locator and two servers with one gateway receiver and a parallel gateway sender. A partitioned region called `/example-region` is also created on each cluster.

1) Create `geode-cluster-1` and `geode-cluster-2` namespaces for both clusters (`helm` cannot create namespaces so they have to be created in advance):
```
$ kubectl create -f namespaces.json
```

2) Deploy clusters:
```
$ helm install --namespace=geode-cluster-1 -f cluster-1-values.yaml geode-kub charts/geode-kub
$ helm install --namespace=geode-cluster-2 -f cluster-2-values.yaml geode-kub charts/geode-kub
```


# Reproduce the issue

*Note*: Following printouts are omitting gateway receiver section in cluster-1 and gateway senders section in cluster-2 for simplicity.

## Example 1

First, perform some `put` operations on `/example-region` in cluster-1 to ensure the senders are connected to receivers on cluster-2.

Check gateways status in both clusters:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | --------------------------------------------------------------
sender-to-2      | 172.17.0.2(server-0:67)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000
sender-to-2      | 172.17.0.9(server-1:47)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000

```

```
Cluster-2 gfsh>list gateways

GatewayReceiver Section

              Member                | Port  | Sender Count | Senders Connected
----------------------------------- | ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------
172.17.0.10(server-1:108)<v1>:41000 | 32000 | 4            | 172.17.0.2(server-0:67)<v1>:41000, 172.17.0.9(server-1:47)<v1>:41000, 172.17.0.9(server-1:47)<v1>:41000, 172.17.0.9(server-1:47)<v1>:41000
172.17.0.3(server-0:53)<v2>:41000   | 32000 | 3            | 172.17.0.9(server-1:47)<v1>:41000, 172.17.0.2(server-0:67)<v1>:41000, 172.17.0.2(server-0:67)<v1>:41000
```

We can see that both senders in cluster-1 have connections to both receivers in cluster-2.

Now, lets stop one server in cluster-2, so one of the receivers will not be available:

```
Cluster-2 gfsh>stop server --name=server-1
Stopping Cache Server running in /server-1 on server-1.server-site2-service.geode-cluster-2.svc.cluster.local[40404] as server-1...
Process ID: 108
Log File: /server-1/server-1.log
.............................................................
Cluster-2 gfsh>
```

If now we check gateways in both clusters:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | -----------------
sender-to-2      | 172.17.0.2(server-0:67)<v1>:41000 | 2                 | Parallel | Running | 0             |
sender-to-2      | 172.17.0.9(server-1:47)<v1>:41000 | 2                 | Parallel | Running | 0             |
```

```
Cluster-2 gfsh>list gateways

GatewayReceiver Section

             Member               | Port  | Sender Count | Senders Connected
--------------------------------- | ----- | ------------ | -----------------
172.17.0.3(server-0:53)<v2>:41000 | 32000 | 0            |

```

We can see that both senders do not have an available receiver, although cluster-2 receiver in server-0 is still working.



## Example 2

This is a special case I saw when reproducing the issue. In this case, each sender is connected only to one receiver:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | --------------------------------------------------------------
sender-to-2      | 172.17.0.2(server-0:51)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000
sender-to-2      | 172.17.0.4(server-1:47)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000

```

```
Cluster-2 gfsh>list gateways

GatewayReceiver Section

              Member               | Port  | Sender Count | Senders Connected
---------------------------------- | ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------
172.17.0.10(server-1:51)<v1>:41000 | 32000 | 4            | 172.17.0.2(server-0:51)<v1>:41000, 172.17.0.2(server-0:51)<v1>:41000, 172.17.0.2(server-0:51)<v1>:41000, 172.17.0.2(server-0:51)<v1>:41000
172.17.0.7(server-0:67)<v1>:41000  | 32000 | 4            | 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000
```

Again, stop one server from cluster-2:

```
Cluster-2 gfsh>stop server --name=server-1
Stopping Cache Server running in /server-1 on server-1.server-site2-service.geode-cluster-2.svc.cluster.local[40404] as server-1...
Process ID: 51
Log File: /server-1/server-1.log
```

And check the gateways status again:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | --------------------------------------------------------------
sender-to-2      | 172.17.0.2(server-0:51)<v1>:41000 | 2                 | Parallel | Running | 0             |
sender-to-2      | 172.17.0.4(server-1:47)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000

```

```
Cluster-2 gfsh>list gateways

GatewayReceiver Section

             Member               | Port  | Sender Count | Senders Connected
--------------------------------- | ----- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------
172.17.0.7(server-0:67)<v1>:41000 | 32000 | 4            | 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000, 172.17.0.4(server-1:47)<v1>:41000
```

In this case, sender in server-1 in cluster-1 is still working due to it had no connections to server-1 in cluster-2.


# Solution

After implementing the solution, the issue is solved:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | -------------------------------------------------------------------------------------------------
sender-to-2      | 172.17.0.5(server-0:65)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000@172.17.0.8(server-0:65)<v2>:41000
sender-to-2      | 172.17.0.7(server-1:46)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000@172.17.0.10(server-1:46)<v1>:41000
```

After stopping `server-0` in cluster-2, one of the senders is not connected to any receiver:

```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | -------------------------------------------------------------------------------------------------
sender-to-2      | 172.17.0.5(server-0:65)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000@172.17.0.10(server-1:46)<v1>:41000
sender-to-2      | 172.17.0.7(server-1:46)<v1>:41000 | 2                 | Parallel | Running | 0             | 

```

But checking again, it can be seen the sender was connected to the other available receiver:
```
Cluster-1 gfsh>list gateways
GatewaySender Section

GatewaySender Id |              Member               | Remote Cluster Id |   Type   | Status  | Queued Events | Receiver Location
---------------- | --------------------------------- | ----------------- | -------- | ------- | ------------- | -------------------------------------------------------------------------------------------------
sender-to-2      | 172.17.0.5(server-0:65)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000@172.17.0.10(server-1:46)<v1>:41000
sender-to-2      | 172.17.0.7(server-1:46)<v1>:41000 | 2                 | Parallel | Running | 0             | receiver-site2-service.geode-cluster-2.svc.cluster.local:32000@172.17.0.10(server-1:46)<v1>:41000

```




# Uninstall environment

Use the `delete-cluster` helper script to delete both clusters:
```
$ ./delete-cluster.sh 1
$ ./delete-cluster.sh 2
```

And finally, remove namespaces:
```
$ kubectl delete namespace geode-cluster-1 geode-cluster-2
```
