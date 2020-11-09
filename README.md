# kafka_logging
Logging from OCP to kafka

## This directory contains instructions to 

* Install Apache Kafka 1.2.0 on Openshift Container Platform 4.x
* Deploy Kafka / Zookeeper
* Install cluster logging and configure it to send messages to kafka

A special thanks goes out to Karan Sing (ksingh7) for his work on kafka.

## Deploying the Cluster Operator on OpenShift

To install AMQ Streams, download and extract the amq-streams-x.y.z-ocp-install-examples.zip file from the [AMQ Streams download site](https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=distributions&product=jboss.amq.streams).


```
oc whoami
oc new-project amq

unzip amq-streams-1.2.0-ocp-install-examples.zip
```

Change the namespace in the unzipped files:
```
sed -i 's/namespace: .*/namespace: amq/' install/cluster-operator/*RoleBinding*.yaml
```
```
oc apply -f install/cluster-operator -n amq
oc apply -f examples/templates/cluster-operator -n amq
watch oc get all
```

## Clone repository
```
git clone https://github.com/mkarg75/kafka_logging.git ; cd kafka-logging/kafka
```

## Deploy the Kafka cluster
```
oc apply -f 01-kafka-ephemeral.yaml
```
```
$ oc get all
NAME                                              READY   STATUS    RESTARTS   AGE
NAME                                            READY   STATUS    RESTARTS   AGE
pod/my-cluster-kafka-0                          0/2     Running   0          10s
pod/my-cluster-kafka-1                          0/2     Running   0          10s
pod/my-cluster-kafka-2                          0/2     Running   0          10s
pod/my-cluster-zookeeper-0                      1/1     Running   0          75s
pod/my-cluster-zookeeper-1                      1/1     Running   0          75s
pod/my-cluster-zookeeper-2                      1/1     Running   0          75s
pod/strimzi-cluster-operator-865fbcd68c-z8c48   1/1     Running   0          38m

NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
service/my-cluster-kafka-bootstrap    ClusterIP   172.30.144.20    <none>        9091/TCP,9092/TCP,9093/TCP,9404/TCP   11s
service/my-cluster-kafka-brokers      ClusterIP   None             <none>        9091/TCP,9092/TCP,9093/TCP            11s
service/my-cluster-zookeeper-client   ClusterIP   172.30.203.148   <none>        9404/TCP,2181/TCP                     75s
service/my-cluster-zookeeper-nodes    ClusterIP   None             <none>        2181/TCP,2888/TCP,3888/TCP            75s

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/strimzi-cluster-operator   1/1     1            1           38m

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/strimzi-cluster-operator-865fbcd68c   1         1         1       38m

NAME                                    READY   AGE
statefulset.apps/my-cluster-kafka       0/3     10s
statefulset.apps/my-cluster-zookeeper   3/3     75s
[kni@e16-h20-b03-fc640 kafka]$ oc get all
NAME                                              READY   STATUS    RESTARTS   AGE
pod/my-cluster-entity-operator-545656b8c7-d2jm5   3/3     Running   0          26s
pod/my-cluster-kafka-0                            2/2     Running   0          53s
pod/my-cluster-kafka-1                            2/2     Running   0          53s
pod/my-cluster-kafka-2                            2/2     Running   0          53s
pod/my-cluster-zookeeper-0                        1/1     Running   0          118s
pod/my-cluster-zookeeper-1                        1/1     Running   0          118s
pod/my-cluster-zookeeper-2                        1/1     Running   0          118s
pod/strimzi-cluster-operator-865fbcd68c-z8c48     1/1     Running   0          39m

NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
service/my-cluster-kafka-bootstrap    ClusterIP   172.30.144.20    <none>        9091/TCP,9092/TCP,9093/TCP,9404/TCP   54s
service/my-cluster-kafka-brokers      ClusterIP   None             <none>        9091/TCP,9092/TCP,9093/TCP            54s
service/my-cluster-zookeeper-client   ClusterIP   172.30.203.148   <none>        9404/TCP,2181/TCP                     118s
service/my-cluster-zookeeper-nodes    ClusterIP   None             <none>        2181/TCP,2888/TCP,3888/TCP            118s

NAME                                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/my-cluster-entity-operator   1/1     1            1           26s
deployment.apps/strimzi-cluster-operator     1/1     1            1           39m

NAME                                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/my-cluster-entity-operator-545656b8c7   1         1         1       26s
replicaset.apps/strimzi-cluster-operator-865fbcd68c     1         1         1       39m

NAME                                    READY   AGE
statefulset.apps/my-cluster-kafka       3/3     53s
statefulset.apps/my-cluster-zookeeper   3/3     118s
```
## Set up Prometheus and Grafana Monitoring
```
oc apply -f 06-prometheus.yaml
oc apply -f 07-grafana.yaml
oc get route
```
Edit `08-grafana-datasource.sh` so that it has the correct grafana endpoint (the route)
```
sh 08-grafana-datasource.sh
```

# Logging

## Deploy the logging operator
```
cd ../logging
oc create -f eo-namespace.yaml
oc create -f clo-namespace.yaml
oc create -f eo-og.yaml
oc create -f eo-sub.yaml

oc create -f clo-og.yaml
oc create -f clo-sub.yaml
oc get csv -n openshift-logging
oc create -f clo-instance.yaml
oc create -f kafka-secret.yaml
```

The last step creates a logging instance that does **not** start Elasticsearch.

## Create a logforwarder to kafka

Get the service from the amq project:
```
oc get service -n amq

NAME                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                               AGE
grafana                       ClusterIP   172.30.40.210    <none>        3000/TCP                              65m
my-cluster-kafka-bootstrap    ClusterIP   172.30.217.243   <none>        9091/TCP,9092/TCP,9093/TCP,9404/TCP   39m
my-cluster-kafka-brokers      ClusterIP   None             <none>        9091/TCP,9092/TCP,9093/TCP            39m
my-cluster-zookeeper-client   ClusterIP   172.30.1.16      <none>        9404/TCP,2181/TCP                     40m
my-cluster-zookeeper-nodes    ClusterIP   None             <none>        2181/TCP,2888/TCP,3888/TCP            40m
prometheus                    ClusterIP   172.30.27.130    <none>        9090/TCP                              65m
```

The required service here is *my-cluster-kafka-bootstrap.amq.svc*. Make sure to change the `clusterforwarder.yaml` accordingly. 

```
oc create -f clusterforwarder.yaml
oc get pods -A -o wide | grep fluentd
```
Every worker and master node in the cluster should have a fluentd pod up and running at this point.


Now check the logs of one of the created fluentd pods
```
oc logs -f -n openshift-logging <fluentd_pod>
...
2020-11-09 12:24:42 +0000 [info]: gem 'fluentd' version '1.7.4'
2020-11-09 12:24:42 +0000 [info]: starting fluentd worker pid=1 ppid=0 worker=0
2020-11-09 12:24:42 +0000 [info]: fluentd worker is now running worker=0
```

If all went well, the pod should send its messages to kafka. 

# TODOs

* tls encrypted traffic to kafka
* cleanup of naming conventions

