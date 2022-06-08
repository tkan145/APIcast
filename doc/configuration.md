# Configuration and its persistence

Gateway needs configuration in order to work. It needs it to determine service configuration, hostname, etc.

Gateway can load the configuration from file, API or write it through management API (for debugging purposes).

## Configuration loading

### File

Can be loaded in `init` and `init_worker` before server starts serving requests. 

### API (autoload)

Can't be used in `init` or `init_worker` as cosocket API is not available. Would have to be pushed to background via `ngx.timer.at`.

### Management API

Can push configuration to the gateway via an API. 

## Configuration storage

Gateway needs to cache the configuration somewhere. Possibly even across restarts.

### Global variable

Just not scalable. Disappears on every request with `lua_code_cache off`.

### Shared Memory

Needs to serialize configuration into a string. Does not survive restarts. Size is allocated on boot. Shared across workers.

### LRU Cache (lua-resty-lrucache)

Does not use shared memory, but has eviction algorithm to keep maximum number of items. Local to the worker.

### File

Can survive restart. Still needs some other method to act as cache.

## Multi-tenancy

3scale hosts thousands of gateways for its customers and needs a reasonable way to share resources between them. Multi-tenant deployment of this proxy is the preferred way.

TODO: figure out how to store/load the configuration in multi-tenant way


## How config is loaded:

The following are the three main components in an APIcast configuration:

- configuration_loader: this is a object that retrieve the configuration and the
  OIDC config for all services, there are a few kinds of loader:
    - file: for using local file and THREESCALE_CONFIG_FILE
    - remote_v1: this is what we used in the past, to load all the config from
      system and spec.json, using THREESCALE_PORTAL_ENDPOINT.
    - remote_v2: this is the best way, will retrieve the config by each service,
      and auto-discover the oidc information, this uses
      THREESCALE_PORTAL_ENDPOINT env variable
- configuration_store: this is the object that stores the configuration into
  the Openresty cache to be used in different phases.
- policy/load-configuration: by default this policy is always loaded, as
  first.It has the same behaviour as any policy, given the following scenario:
    - init phase: started the configuration_store
    - init_worker phase: retrieved the config using configuration_loader and send the
      configuration_store object, so can save the config retrieved.
    - rewrite phase: look for the service for the request host, and set the
      service config on that request.

