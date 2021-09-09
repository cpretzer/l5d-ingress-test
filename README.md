This is a scaleable test harness for observing the linkerd proxy behavior
through an nginx ingress under configurable amounts of load

# Requirements
- [k3d](https://k3d.io)
- [Linkerd](https://linkerd.io)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

# Quick Start
- Verify that you have the dependencies above
- run `./deploy.sh` (this will take a few minutes)
- run `linkerd viz stat -n backpressure-test`

# How it works
The `deploy.sh` script:
- checks that the requirements above are met
- creates a new k3d cluster named `backpressure-test`
- deploys [Linkerd](Ihttps://linkerd.io) and the `Linkerd-Viz` extensions to the
 cluster
- deploys the nginx ingress controller
- injects the ingress controller with the `Linkerd` proxy
- applies `k8s/backpressure.yml` 

## Workloads and Configuration
The `k8s/backpressure.yml` file defines `Deployment` resources for [slow_cooker](https://github.com/buoyantio/slow_cooker) and [bb](https://github.com/buoyantio/bb),
where slow_cooker is a load generator that sends traffic through
the nginx ingress to the bb `Service` via an `Ingress` resource.

The initial configuration of the slow_cooker uses 100 threads to send 1 request,
which is 100 requests per second:

```yaml
...
        args:
        - "-concurrency=100"
        - "-interval=30s"
        - "-noLatencySummary"
        - "-qps=1"
        - "http://ingress-nginx-controller.ingress-nginx"
...    
```

The bb deployment is configured in `terminus` mode to handle HTTP/1.1 traffic
and respond after a 100ms delay:

```yaml
...
        args: 
        - "terminus"
        - "--h1-server-port"
        - "9090"
        - "--response-text"
        - "BANANA"
        - "--sleep-in-millis"
        - "100"
...
```

To test the behavior described in [this issue](https://github.com/linkerd/linkerd2/issues/6441)
read [MEMORY_TEST.md](MEMORY_TEST)

# Future Work
- Add more slow_cooker types to slowly scale load
- Make cpu and memory limits configurable
- write better bash