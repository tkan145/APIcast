# APIcast parameters

APIcast v2 has a number of parameters configured as [environment variables](#environment-variables) that can modify the behavior of the gateway. The following reference provides descriptions of these parameters.

Note that when deploying APIcast v2 with OpenShift, some of these parameters can be configured via OpenShift template parameters. The latter can be consulted directly in the [template](https://raw.githubusercontent.com/3scale/apicast/master/openshift/apicast-template.yml).

## Environment variables

### `APICAST_BACKEND_CACHE_HANDLER`

**Values:** strict | resilient
**Default:** strict
**Deprecated:** Use [Caching](../gateway/src/apicast/policy/caching/apicast-policy.json) policy instead.

Defines how the authorization cache behaves when backend is unavailable.
Strict will remove cached application when backend is unavailable.
Resilient will do so only on getting authorization denied from backend.

### `APICAST_CONFIGURATION_CACHE`

**Values:** _a number_
**Default:** 0

Specifies the period (in seconds) that the configuration will be stored in the cache for. Can take the following values:
- `0`: disables the cache. The configuration will not be not stored. This is not compatible with `boot` mode of `APICAST_CONFIGURATION_LOADER` parameter. When used together with `lazy` value of `APICAST_CONFIGURATION_LOADER`, APIcast will reload the configuration on every request.
- a positive number ( > 0 ): specifies the interval in seconds between configuration reload. For example, when APIcast is started with `APICAST_CONFIGURATION_CACHE=300` and `APICAST_CONFIGURATION_CACHE=boot`, it will load the configuration on boot, and will reload it every 5 minutes (300 seconds).
- a negative number ( < 0 ): disables reloading. The cache entries will never be removed from the cache once stored, and the configuration will never be reloaded.

This parameter is also used to store OpenID discovery configuration in the local cache, as the same behavior as described above.

### `APICAST_SERVICE_CACHE_SIZE`

**Values:** _a number_
**Default:** 1000

Specifies the number of services that APICast can store in the internal cache. A
big number has a performance impact because Lua lru cache will
initialize all the entries.

### `APICAST_CONFIGURATION_LOADER`

**Values:** boot | lazy
**Default:** lazy

Defines how to load the configuration.
In `boot` mode APIcast will request the configuration to the API manager when the gateway starts.
In `lazy` mode APIcast will load the configuration on demand for each incoming request (to guarantee a complete refresh on each request `APICAST_CONFIGURATION_CACHE` should be set to `0`).


### `APICAST_CUSTOM_CONFIG`

**Deprecated:** Use [policies](./policies.md) instead.

Defines the name of the Lua module that implements custom logic overriding the existing APIcast logic.

### `APICAST_ENVIRONMENT`

**Default:**
**Value:** string\[:<string>\]
**Example:** production:cloud-hosted

Double colon (`:`) separated list of environments (or paths) APIcast should load.
It can be used instead of `-e` or `---environment` parameter on the CLI and for example
stored in the container image as default environment. Any value passed on the CLI overrides this variable.

### `APICAST_LOG_FILE`

**Default:** _stderr_

Defines the file that will store the OpenResty error log. It is used by `bin/apicast` in the `error_log` directive. Refer to [NGINX documentation](http://nginx.org/en/docs/ngx_core_module.html#error_log) for more information. The file path can be either absolute, or relative to the prefix directory (`apicast` by default)

### `APICAST_LOG_LEVEL`

**Values:** debug | info | notice | warn | error | crit | alert | emerg
**Default:** warn

Specifies the log level for the OpenResty logs.

### `APICAST_ACCESS_LOG_FILE`

**Default:** _stdout_

Defines the file that will store the access logs.


### APICAST_ACCESS_LOG_BUFFER

**Values:** integer
**Default**: nil

Allows access log writes to be included in chunks of bytes, resulting on fewer system calls
that improve the performance of the whole gateway.


### `APICAST_OIDC_LOG_LEVEL`

**Values:** debug | info | notice | warn | err | crit | alert | emerg
**Default:** err

Allows to set the log level for the logs related to OpenID Connect integration


### `APICAST_MANAGEMENT_API`

**Values:**

- `disabled`: completely disabled, just listens on the port
- `status`: enables the `/status/` endpoint for health checks, and the `/policies` endpoint that shows the list of available policies.
- `policies`: enables only the `/policies` endpoint.
- `debug`: full API is open

The [Management API](./management-api.md) is powerful and can control the APIcast configuration.
You should enable the debug level only for debugging.

### `APICAST_PATH_ROUTING`

**Values:**
- `true` or `1` for _true_
- `false`, `0` or empty for _false_

When this parameter is set to _true_, the gateway will use path-based routing in addition to the default host-based routing. The API request will be routed to the first service that has a matching mapping rule, from the list of services for which the value of the `Host` header of the request matches the _Public Base URL_.

### `APICAST_PATH_ROUTING_ONLY`

**Values:**
- `true` or `1` for _true_
- `false`, `0` or empty for _false_

When this parameter is set to _true_, the gateway uses path-based routing and will not fallback to the default host-based routing. The API request will be routed to the first service that has a matching mapping rule, from the list of services for which the value of the `Host` header of the request matches the _Public Base URL_.

This parameter has precedence over `APICAST_PATH_ROUTING`. If `APICAST_PATH_ROUTING_ONLY` is enabled, APIcast will only do path-based routing regardless of the value of `APICAST_PATH_ROUTING`.

### `APICAST_POLICY_LOAD_PATH`

**Default**: `APICAST_DIR/policies`
**Value:**: string\[:<string>\]
**Example**: `~/apicast/policies:$PWD/policies`

Double colon (`:`) separated list of paths where APIcast should look for policies.
It can be used to first load policies from a development directory or to load examples.

### `APICAST_PROXY_HTTPS_CERTIFICATE_KEY`

**Default:**
**Value:** string
**Example:** /home/apicast/my_certificate.key

The path to the key of the client SSL certificate.

This parameter can be overridden by the Upstream_TLS policy.

### `APICAST_PROXY_HTTPS_CERTIFICATE`

**Default:**
**Value:** string
**Example:** /home/apicast/my_certificate.crt

The path to the client SSL certificate that APIcast will use when connecting
with the upstream. Notice that this certificate will be used for all the
services in the configuration.

This parameter can be overridden by the Upstream_TLS policy.

### `APICAST_PROXY_HTTPS_PASSWORD_FILE`

**Default:**
**Value:** string
**Example:** /home/apicast/passwords.txt

Path to a file with passphrases for the SSL cert keys specified with
`APICAST_PROXY_HTTPS_CERTIFICATE_KEY`.

### `APICAST_PROXY_HTTPS_SESSION_REUSE`

**Default:** on
**Values:**
- `on`: reuses SSL sessions.
- `off`: does not reuse SSL sessions.

### `APICAST_REPORTING_THREADS`

**Default**: 0
**Value:** integer >= 0
**Experimental:** Under extreme load might have unpredictable performance and lose reports.

Value greater than 0 is going to enable out-of-band reporting to backend.
This is a new **experimental** feature for increasing performance. Client
won't see the backend latency and everything will be processed asynchronously.
This value determines how many asynchronous reports can be running simultaneously
before the client is throttled by adding latency.

### `APICAST_RESPONSE_CODES`

**Values:**
- `true` or `1` for _true_
- `false`, `0` or empty for _false_

**Default:** \<empty\> (_false_)

When set to _true_, APIcast will log the response code of the response returned by the API backend in 3scale. In some plans this information can later be consulted from the 3scale admin portal.
Find more information about the Response Codes feature on the [3scale support site](https://access.redhat.com/documentation/en-us/red_hat_3scale/2-saas/html-single/admin_portal_guide/index#response-codes-tracking).

### `APICAST_SERVICES_FILTER_BY_URL`
**Value:** a PCRE (Perl Compatible Regular Expression)
**Example:** .*.example.com

Used to filter the service configured in the 3scale API Manager, the filter
matches with the public base URL (Staging or production). Services that do not
match the filter will be discarded. If the regular expression cannot be compiled
no services will be loaded.

Note: If a service does not match, but is included in the
`APICAST_SERVICES_LIST`, service will not be discarded

Example:

Regexp Filter: http:\/\/.*.api.foo
Service 1: backend endpoint http://www.api.foo
Service 2: backend endpoint http://www.api.bar
Service 3: backend endpoint http://mail.api.foo
Service 4: backend endpoint http://mail.api.bar

The services that will be configured in APIcast will be 1 and 3. Services 2 and
4 will be discarded.

### `APICAST_SERVICES_LIST`
**Value:** a comma-separated list of service IDs

Used to filter the services configured in the 3scale API Manager, and only use the configuration for specific services in the gateway, discarding those services' IDs that are not specified in the list.
Service IDs can be found on the **Dashboard > APIs** page, tagged as _ID for API calls_.

### `APICAST_SERVICE_${ID}_CONFIGURATION_VERSION`

Replace `${ID}` with the actual Service ID. The value should be the configuration version you can see in the configuration history on the Admin Portal.

Setting it to a particular version will prevent it from auto-updating and will always use that version.

**Note**: This env var cannot be used with `THREESCALE_PORTAL_ENDPOINT` pointing to custom path (i.e. master path).

### `APICAST_UPSTREAM_RETRY_CASES`

**Default**:
**Values**: error | timeout | invalid_header | http_500 | http_502 | http_503 | http_504 | http_403 | http_404 | http_429 | non_idempotent | off

Used only when the retry policy is configured. Specified in which cases a request to the upstream API should be retried.
This accepts the same values as https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_next_upstream

### `APICAST_WORKERS`

**Default:** auto
**Values:** _number_ | auto

This is the value that will be used in the nginx `worker_processes` [directive](http://nginx.org/en/docs/ngx_core_module.html#worker_processes). By default, APIcast uses `auto`, except for the development environment where `1` is used.

### `BACKEND_ENDPOINT_OVERRIDE`

URI that overrides the backend endpoint. By default, it is the external route.
This parameter is useful when deploying APIcast into the same OpenShift cluster than 3scale, as when using the internal hostname of the backend listener service instead of the public route.

**Example**: `http://backend-listener.<3scale-namespace>.svc.cluster.local:3000`

### `OPENSSL_VERIFY`

**Values:**
- `0`, `false`: disable peer verification
- `1`, `true`: enable peer verification

Controls the OpenSSL Peer Verification. It is off by default, because OpenSSL can't use system certificate store.
It requires custom certificate bundle and adding it to trusted certificates.

It is recommended to use https://github.com/openresty/lua-nginx-module#lua_ssl_trusted_certificate and point to to
certificate bundle generated by [export-builtin-trusted-certs](https://github.com/openresty/openresty-devel-utils/blob/master/export-builtin-trusted-certs).

### `REDIS_HOST`

**Default:** `127.0.0.1`

APIcast requires a running Redis instance for OAuth 2.0 Authorization code flow. `REDIS_HOST` parameter is used to set the hostname of the IP of the Redis instance.

### `REDIS_PORT`

**Default:** 6379

APIcast requires a running Redis instance for OAuth 2.0 Authorization code flow. `REDIS_PORT` parameter can be used to set the port of the Redis instance.

### `REDIS_URL`

**Default:** no value

APIcast requires a running Redis instance for OAuth 2.0 Authorization code flow. `REDIS_URL` parameter can be used to set the full URI as DSN format like: `redis://PASSWORD@HOST:PORT/DB`. Takes precedence over `REDIS_PORT` and `REDIS_HOST`.

### `RESOLVER`

Allows to specify a custom DNS resolver that will be used by OpenResty. If the `RESOLVER` parameter is empty, the DNS resolver will be autodiscovered.

### `THREESCALE_CONFIG_FILE`

Path to the JSON file with the configuration for the gateway. The configuration can be downloaded from the 3scale admin portal using the URL: `<schema>://<admin-portal-domain>/admin/api/nginx/spec.json` (**Example**: `https://account-admin.3scale.net/admin/api/nginx/spec.json`).

When the gateway is deployed using Docker, the file has to be injected to the docker image as a read only volume, and the path should indicate where the volume is mounted, i.e. path local to the docker container.

You can find sample configuration files in [examples](https://github.com/3scale/apicast/tree/master/examples/configuration) folder.

It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.

### `THREESCALE_DEPLOYMENT_ENV`

**Values:** staging | production
**Default:** production

The value of this environment variable will be used to define the environment for which the configuration will be downloaded from 3scale (Staging or Production), when using new APIcast.

The value will also be used in the header `X-3scale-User-Agent` in the authorize/report requests made to 3scale Service Management API. It is used by 3scale just for statistics.

### `THREESCALE_PORTAL_ENDPOINT`

URI that includes your password and portal endpoint in the following format: `<schema>://<password>@<admin-portal-domain>`. The `<password>` can be either the provider key or an access token for the 3scale Account Management API. `<admin-portal-domain>` is the URL used to log into the admin portal.

The path appended to `THREESCALE_PORTAL_ENDPOINT` is:

|                      | `APICAST_CONFIGURATION_LOADER`=boot                            | `APICAST_CONFIGURATION_LOADER`=lazy                                     |
|----------------------|----------------------------------------------------------------|-------------------------------------------------------------------------|
| endpoint has no path | `/admin/api/account/proxy_configs/${env}.json?version=version&page=X&per_page=500` | `/admin/api/account/proxy_configs/${env}.json?host=host&version=version&page=X&per_page=500` |
| endpoint has a path  | `/${env}.json`                                                 | `/${env}.json?host=host`                                                 |

The exception to the logic in table above would be when the env var `APICAST_SERVICE_%s_CONFIGURATION_VERSION` is provided.
In that case, the gateway would load service's proxy configuration one by one:
* 1 request to `/admin/api/services.json?page=X&per_page=500` (which is paginated and the gateway will iterate over the pages)
* N requests to `/admin/api/services/${SERVICE_ID}/proxy/configs/${ENVIRONMENT}/{VERSION}.json`.

Note that when the `THREESCALE_PORTAL_ENDPOINT` has no path, the gateway will iterate over the pages of `/admin/api/account/proxy_configs/${env}.json` sending `pages` and `per_page` query parameters.

**Note**: Pages in 3scale API services and proxy config endpoints were implemented on 3scale 2.10 [THREESCALE-4528](https://issues.redhat.com/browse/THREESCALE-4528). Older releases should not be used.

**Example:** `https://access-token@account-admin.3scale.net`.

When `THREESCALE_PORTAL_ENDPOINT` environment variable is provided, the gateway will download the configuration from 3scale on initializing. The configuration includes all the settings provided on the Integration page of the API(s).

It is **required** to provide either `THREESCALE_PORTAL_ENDPOINT` or `THREESCALE_CONFIG_FILE` (takes precedence) for the gateway to run successfully.

### `APICAST_HTTPS_PORT`

**Default:** no value

Controls on which port APIcast should start listening for HTTPS connections. If this clashes with HTTP port it will be used only for HTTPS.

### `APICAST_HTTPS_CERTIFICATE`

**Default:** no value

Path to a file with X.509 certificate in the PEM format for HTTPS.

### `APICAST_HTTPS_CERTIFICATE_KEY`

**Default:** no value

Path to a file with the X.509 certificate secret key in the PEM format.

### `APICAST_HTTPS_VERIFY_DEPTH`

**Default:** 1
**Values:** positive integers

Defines the maximum length of the client certificate chain.
If this parameter has `1` as its value, it is possible to include an additional certificate in the client certificate chain. For example, root certificate authority.

### `APICAST_HTTPS_VERIFY_CLIENT`

**Default:** `optional_no_ca`
**Values:**
- `off`: Do not request client certificates or perform client certificate verification.
- `optional_no_ca`: Requests the client certificate, but does not fail the request when the client certificate is not signed by a trusted CA certificate.

Enables verification of client certificates. You can verify client certificates TLS Client Certificate Validation policy.

### `all_proxy`, `ALL_PROXY`

**Default:** no value
**Value:** string
**Example:** `http://forward-proxy:80`

Defines a HTTP proxy to be used for connecting to services if a protocol-specific proxy is not specified. Authentication is not supported.

### `http_proxy`, `HTTP_PROXY`

**Default:** no value
**Value:** string
**Example:** `http://forward-proxy:80`

Defines a HTTP proxy to be used for connecting to HTTP services. Authentication is not supported.

### `https_proxy`, `HTTPS_PROXY`

**Default:** no value
**Value:** string
**Example:** `http://forward-proxy:80`

Defines a HTTP proxy to be used for connecting to HTTPS services. Authentication is not supported.

### `no_proxy`, `NO_PROXY`

**Default:** no value
**Values:** string\[,<string>\]; `*`
**Example:** `foo,bar.com,.extra.dot.com`

Defines a comma-separated list of hostnames and domain names for which the requests should not be proxied. Setting to a single `*` character, which matches all hosts, effectively disables the proxy.

### `APICAST_HTTP_PROXY_PROTOCOL`

**Default:** false
**Values:** boolean
**Example:** "true"

This parameter enables the Proxy Protocol for the HTTP listener.

### `APICAST_HTTPS_PROXY_PROTOCOL`

**Default:** false
**Values:** boolean
**Example:** "true"

This parameter enables the Proxy Protocol for the HTTPS listener.

### `APICAST_EXTENDED_METRICS`

**Default:** false
**Value:** boolean
**Example:** "true"

Enables additional information on Prometheus metrics; some labels will be used
with specific information that will provide more in-depth details about APIcast.

The metrics that will have extended information are:

- total_response_time_seconds: labels service_id and service_system_name
- upstream_response_time_seconds: labels service_id and service_system_name
- upstream_status: labels service_id and service_system_name

### `HTTP_KEEPALIVE_TIMEOUT`

**Default:** 75
**Value:** positive integers
**Example:** "1"

This parameter sets a timeout during which a keep-alive client connection will
stay open on the server side. The zero value disables keep-alive client
connections.

By default Gateway does not enable it, and the keepalive timeout on nginx is set
to [75 seconds](http://nginx.org/en/docs/http/ngx_http_core_module.html#keepalive_timeout)

### `APICAST_LUA_SOCKET_KEEPALIVE_REQUESTS`

**Value:** positive integers
**Example:** "1"

Sets the maximum number of requests that one keepalive connection can serve.
After reaching the limit, the connection closes.

NOTE: This value affects connections opened by APIcast and will not have any
impact on requests proxied via APIcast.

### `APICAST_CACHE_STATUS_CODES`

**Default:** 200 302
**Value:** string

When the response code from upstream matches one of the status codes defined in
this environment variable, the response content will be cached in NGINX for the
Headers cache time value, or the maximum time defined by
`APICAST_CACHE_MAX_TIME` env variable.

This parameter is only used by the services that are using content caching
policy.

### `APICAST_CACHE_MAX_TIME`

**Default:** 1m
**Value:** string

When the response is selected to be cached in the system, the value of this
variable indicates the maximum time to be cached. If cache-control header is not
set, the time to be cached will be the defined one.

The format for this value is defined by the [`proxy_cache_valid` NGINX
directive](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_valid)

This parameter is only used by the services that are using content caching
policy.

### `APICAST_LARGE_CLIENT_HEADER_BUFFERS`

**Default:** 4 8k
**Value:** string

Sets the maximum number and size of buffers used for reading large client request header.

The format for this value is defined by the [`large_client_header_buffers` NGINX
directive](https://nginx.org/en/docs/http/ngx_http_core_module.html#large_client_header_buffers)

### `APICAST_POLICY_BATCHER_SHARED_MEMORY_SIZE`

**Default:** 20m
**Value:** string

Sets the maximum size of shared memory used by batcher policy. The accepted [size units](https://github.com/openresty/lua-nginx-module?tab=readme-ov-file#lua_shared_dict) are k and m.

### `APICAST_PROXY_BUFFER_SIZE`

**Default:** 4k|8k;
**Value:** string

Sets the size of the buffer used for handling the response received from the proxied server. This variable sets both [`proxy_buffer` NGINX directive](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffers) and [`proxy_buffer_size` NGINX directive](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_buffer_size). By default, the buffer size is equal to one memory page. This is either 4 KiB or 8 KiB, depending on a platform.

### `OPENTELEMETRY`

This environment variable enables NGINX instrumentation using OpenTelemetry tracing library.
It works with [Jaeger](https://www.jaegertracing.io/) since version 1.35.
If the existing collector does not support OpenTelemetry traces, an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) is required as tracing proxy.

If empty or not set, Nginx instrumentation with OpenTelemetry is disabled.

Currently, the only implemeneted [exporter](https://opentelemetry.io/docs/reference/specification/protocol/exporter/)
in APIcast is OTLP over gRPC `OTLP/gRPC`. Even though OpenTelemetry specification supports also OTLP over HTTP (`OTLP/HTTP`),
this exporter is not included in APIcast.

Supported propagation types: [W3C](https://w3c.github.io/trace-context/)

### `OPENTELEMETRY_CONFIG`

**Example:** `/tmp/otel.toml`

This environment variable provides location of the configuration file for the tracer. If `OPENTELEMETRY` is not set, this variable will be ignored.

The configuration file specification is defined in the [Nginx instrumentation library repo](https://github.com/open-telemetry/opentelemetry-cpp-contrib/tree/main/instrumentation/nginx).

`otlp` is the only supported exporter.

Configuration example

```toml
exporter = "otlp"
processor = "batch"

[exporters.otlp]
# Alternatively, the OTEL_EXPORTER_OTLP_ENDPOINT environment variable can also be used.
host = "localhost"
port = 4317

[processors.batch]
max_queue_size = 2048
schedule_delay_millis = 5000
max_export_batch_size = 512

[service]
name = "apicast" # Opentelemetry resource name

[sampler]
name = "AlwaysOn" # Also: AlwaysOff, TraceIdRatioBased
ratio = 0.1
parent_based = false
```
