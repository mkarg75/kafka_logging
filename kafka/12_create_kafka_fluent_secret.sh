oc -n amq get secret my-cluster-cluster-ca-cert -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
oc create secret generic kafka-fluent --from-file=ca-bundle.crt=ca.crt  -n openshift-logging
