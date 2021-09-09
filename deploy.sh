#! /bin/bash

set -eu
set -x

export CLUSTER_NAME="${CLUSTER:-backpressure-test}"

require_from() {
    echo "Checking for $1"
    if ! command -v "$1" >/dev/null 2>/dev/null ; then
        echo "Please acquire $1 from $2" >&2
        exit 1
    fi
}

find_or_create_k3d_cluster() {
    # check for k3d
    k3d version

    # create a k3d cluster
    if k3d cluster get "$CLUSTER_NAME" > /dev/null 2>/dev/null; then 
        echo "k3d cluster $CLUSTER_NAME exists"
    else
        echo "Creating cluster $CLUSTER_NAME"
        k3d cluster create $CLUSTER_NAME --wait
    fi
}

install_linkerd() {
    # Check linkerd version
    linkerd version

    # Run linkerd pre-check (assumes cluster is running)
    linkerd check --pre

    # Install linkerd
    linkerd install \
    --proxy-cpu-request 100m \
    --proxy-memory-request 20Mi \
    --proxy-memory-limit 250Mi | kubectl apply -f -

    # HACK: sleep before calling wait
    sleep 10

    # Wait for linkerd control plane
    kubectl wait -n linkerd \
    --for=condition=ready pod \
    --selector=linkerd.io/control-plane-ns=linkerd \
    --timeout=240s

    # Install linkerd viz
    linkerd viz install | kubectl apply -f -

    # HACK: sleep before calling wait
    sleep 5

    # wait for linkerd viz (may not be necessary)
    kubectl wait -n linkerd-viz \
    --for=condition=ready pod \
    --selector=linkerd.io/extension=viz \
    --timeout=120s
}

install_nginx_ingress() {
    # Install nginx ingress
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.0/deploy/static/provider/cloud/deploy.yaml

    # Wait for ingress to start
    kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

    # Inject the ingress controller with Linkerd
    kubectl get deploy -n ingress-nginx -oyaml | linkerd inject - | kubectl apply -f -

    # Wait for ingress to start
    kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s

}

## check for required software
# linkerd
# kubectl 
# k3d

require_from linkerd "curl -sL https://run.linkerd.io/install | sh"
require_from kubectl "https://kubernetes.io/docs/tasks/tools/#kubectl"
require_from k3d "https://k3d.io/stable/#installation"

find_or_create_k3d_cluster

# check kubectl and cluster version
kubectl version --short

install_linkerd
install_nginx_ingress

# deploy slow_cooker and bb
kubectl apply -f k8s/backpressure.yml

# Grafana/Prometheus query
# sum(container_memory_usage_bytes{namespace=~"backpressure-test|default",container="linkerd-proxy"}) by (pod)