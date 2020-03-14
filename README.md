# Jaeger tracer extension for Envoy

## About

This repository provides a [Docker image](https://hub.docker.com/r/yskopets/envoy-jaeger-tracer)
with [Jaeger tracer](https://github.com/jaegertracing/jaeger-client-cpp)
extension for [Envoy](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/jaeger_native_tracing).

## Context

Since `v1.13.0` `Envoy` has switched from `libstdc++` (gcc) to `libc++` (clang).

In practice, it means that dynamically loadable tracer implementations, such as
[Jaeger tracer](https://github.com/jaegertracing/jaeger-client-cpp),
MUST be re-compiled against `libc++` (clang) as well.

This repository serves as an example how it could be done.

## How to use Jaeger tracer extension

Add `Jaeger tracer` extension to a Docker image with `Envoy`:

```
## Image with pre-built Jaeger tracer extension.
## See https://github.com/jaegertracing/jaeger-client-cpp
FROM yskopets/envoy-jaeger-tracer:0.4.2-1.13.0-0 AS jaeger-tracer

## Image with pre-built Envoy binary.
FROM envoyproxy/envoy:latest

# Notice that Jaeger tracer extension is linked against 'libc++' dynamically.
# Because of this, we have to install 'libc++' and 'libc++abi' libraries.
RUN apt-get update     \
 && apt-get install -y \
      libc++1          \
      libc++abi1       \
 && rm -rf /var/lib/apt/lists/*

COPY --from=jaeger-tracer /libjaegertracing_plugin.so /usr/local/lib/envoy/libjaegertracing_plugin.so
```

To verify that `Envoy` can successfully load and use `Jaeger tracer` extension,
use the following sample configuration:

```yaml
admin:
  access_log_path: /dev/null
  address:
    socket_address:
      protocol: TCP
      address: 127.0.0.1
      port_value: 9901
static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        protocol: TCP
        address: 0.0.0.0
        port_value: 10000
    filter_chains:
    - filters:
      - name: envoy.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
          stat_prefix: egress_http
          tracing: {}  # enable tracing
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  host_rewrite: www.google.com
                  cluster: service_google
          http_filters:
          - name: envoy.router
    traffic_direction: OUTBOUND
  clusters:
  - name: service_google
    connect_timeout: 0.25s
    type: LOGICAL_DNS
    # Comment out the following line to test on v6 networks
    dns_lookup_family: V4_ONLY
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: service_google
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: www.google.com
                port_value: 443
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.api.v2.auth.UpstreamTlsContext
        sni: www.google.com

tracing:
  http:
    name: envoy.dynamic.ot
    typed_config:
      "@type": type.googleapis.com/envoy.config.trace.v2.DynamicOtConfig
      library: /usr/local/lib/envoy/libjaegertracing_plugin.so
      config:
        service_name: egress-proxy
        sampler:
          type: const
          param: 1
        reporter:
          localAgentHostPort: 127.0.0.1:6831
        headers:
          jaegerDebugHeader: jaeger-debug-id
          jaegerBaggageHeader: jaeger-baggage
          traceBaggageHeaderPrefix: uberctx-
        baggage_restrictions:
          denyBaggageOnInitializationFailure: false
          hostPort: ""
```

## Next steps

For a complete example how to use `Jaeger tracer` extension
refer to the `Envoy` [documentation](https://www.envoyproxy.io/docs/envoy/latest/start/sandboxes/jaeger_native_tracing).
