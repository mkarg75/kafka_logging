# kafka_logging
Logging from OCP to kafka

## This directory contains instructions to 

* Install cluster logging and configure it to send messages to kafka
* Install Apache Kafka 1.2.0 on Openshift Container Platform 4.x
* Deploy Kafka / Zookeeper

A special thanks goes out to Karan Sing (ksingh7) for his work on kafka.

## Clone repository
```
git clone https://github.com/mkarg75/kafka_logging.git 
```

# Logging

## Deploy the logging operator
```
cd kafka-logging/logging
oc create -f 01-eo-namespace.yaml
oc create -f 02-clo-namespace.yaml
oc create -f 03-eo-og.yaml
oc create -f 04-eo-sub.yaml

oc create -f 05-clo-og.yaml
oc create -f 06-clo-sub.yaml
oc create -f 07-clo-instance.yaml
oc create -f 08-kafka-secret.yaml

oc get all -n openshift-logging
```

The last step creates a logging instance that does **not** start Elasticsearch.

## Deploy kafka  on OpenShift

To deploy a kafka cluster, we need to follow these steps:

```
oc create -f 01-kafka-namespace.yaml
oc create -f 02-kafka-og.yaml 
oc create -f 03-kafka-sub-streams.yaml
oc create -f 04-kafka-cluster.yaml
```

Wait until all the resources are available:
```
oc get all -n amq
NAME                                                       READY   STATUS    RESTARTS   AGE
pod/amq-streams-cluster-operator-v1.5.3-5d87546f58-pdvw6   1/1     Running   0          14m
pod/my-cluster-entity-operator-84b9bf7f9d-9nbpt            3/3     Running   0          13m
pod/my-cluster-kafka-0                                     2/2     Running   0          13m
pod/my-cluster-kafka-1                                     2/2     Running   0          13m
pod/my-cluster-kafka-2                                     2/2     Running   0          13m
pod/my-cluster-zookeeper-0                                 1/1     Running   0          14m
pod/my-cluster-zookeeper-1                                 1/1     Running   0          14m
pod/my-cluster-zookeeper-2                                 1/1     Running   0          14m

NAME                                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/my-cluster-kafka-bootstrap    ClusterIP   172.30.132.163   <none>        9091/TCP,9092/TCP,9093/TCP   13m
service/my-cluster-kafka-brokers      ClusterIP   None             <none>        9091/TCP,9092/TCP,9093/TCP   13m
service/my-cluster-zookeeper-client   ClusterIP   172.30.70.35     <none>        2181/TCP                     14m
service/my-cluster-zookeeper-nodes    ClusterIP   None             <none>        2181/TCP,2888/TCP,3888/TCP   14m

NAME                                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/amq-streams-cluster-operator-v1.5.3   1/1     1            1           14m
deployment.apps/my-cluster-entity-operator            1/1     1            1           13m

NAME                                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/amq-streams-cluster-operator-v1.5.3-5d87546f58   1         1         1       14m
replicaset.apps/my-cluster-entity-operator-84b9bf7f9d            1         1         1       13m

NAME                                    READY   AGE
statefulset.apps/my-cluster-kafka       3/3     13m
statefulset.apps/my-cluster-zookeeper   3/3     14m
```

Now that the kafka cluster is running, we need to create the topics we want to log to and the bridges:
```
oc create -f 05-kafka-topics.yaml
oc create -f 06-kafka-bridges.yaml
```

## Create a logging instance
```
oc create -f 11-cr-cluster-logging.yaml
```

Retrieve the CA and create a secret for kafka - fluent:
```
bash 12_create_kafka_fluent_secret.sh
oc create -f 13-cr-logforwarding-to-kafka-topics.yaml
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

## Setup a consumer for the logs

We're only interested in the app logs for now, so we need to set up a consumer for those:
```
oc process -f 20_topic_consumer.yaml | oc create -f -
```

If the other topics should also be consumed, run these command:

```
oc process -f 20_topic_consumer.yaml -p KAFKA_TOPIC=topic-logging-alert -p CONSUMER_GROUP=alert-consumer | oc create -f -
oc process -f 20_topic_consumer.yaml -p KAFKA_TOPIC=topic-logging-infra -p CONSUMER_GROUP=infra-consumer | oc create -f -
```

## Setup kafka-minion as a prometheus exporter

```
oc create -f 30_minion.yaml
```
This will bring up a kafka minion deployment that needs to be made accessible through a service
```
oc create -f 31_minion_service.yaml
```

## Enable user workload monitoring in OCP

kafka-minion is a prometheus exporter that we need to integrate as a datasource. For that we need to enable user monitoring first:

```
oc create -f 40_user_workload_monitoring.yaml
oc create -f 41_service_monitor.yaml
```
Once this is done, the metrics should be available through Thanos. To use them in grafana, we need to set up an additional data source. For that we need the token and the route to thanos
```
oc sa get-token prometheus-k8s -n openshift-monitoring
oc get route -n openshift-monitoring | grep thanos-querier | awk '{print $2}'
```
Now add a new datasource of the type 'Prometheus', url is https://<thanos-querier-route>/. Enable "Skip TLS Verify" and add a new header `Authorization` with the value of `Bearer <token_from_above>`

Then import these 2 dashboards, pointing them to the new datasource:

https://grafana.com/dashboards/10083
https://grafana.com/dashboards/10466

and enjoy your metrics!


# TODOs

add persistent storage for kafka to use


