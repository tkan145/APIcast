local format = string.format
local var = ngx.var

local resty_url = require "resty.url"
local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'
local http_proxy = require 'resty.http.proxy'
local file_reader = require("resty.file").file_reader
local concat = table.concat

local _M = { }

function _M.reset()
    _M.balancer = round_robin.new()
    _M.resolver = resty_resolver
    _M.http_backend = require('resty.http_ng.backend.resty')
    _M.dns_resolution = 'apicast' -- can be set to 'proxy' to let proxy do the name resolution

    return _M
end

local function resolve_servers(uri)
    local resolver = _M.resolver:instance()

    if not resolver then
        return nil, 'not initialized'
    end

    if not uri then
        return nil, 'no url'
    end

    return resolver:get_servers(uri.host, uri)
end

function _M.resolve(uri)
    local balancer = _M.balancer

    if not balancer then
        return nil, 'not initialized'
    end

    local servers, err = resolve_servers(uri)

    if err then
        return nil, err
    end

    local peers = balancer:peers(servers)
    local peer = balancer:select_peer(peers)

    local ip = uri.host
    local port = uri.port

    if peer then
        ip = peer[1]
        port = peer[2]
    end

    return ip, port
end

-- #TODO: This local function is no longer called as of PR#1323 and should be removed
local function resolve(uri)
    local host = uri.host
    local port = uri.port

    if _M.dns_resolution == 'apicast' then
        host, port = _M.resolve(uri)
    end

    return host, port or resty_url.default_port(uri.scheme)
end

local function absolute_url(uri)
-- target server requires hostname not IP and DNS resolution is left to the proxy itself as specified in the RFC #7231
-- https://httpwg.org/specs/rfc7231.html#CONNECT
    return format('%s://%s:%s%s',
            uri.scheme,
            uri.host,
            uri.port,
            uri.path or '/'
    )
end

local function forward_https_request(proxy_uri, proxy_auth, uri, skip_https_connect)
    ngx.req.set_header("X-Real-IP", var.remote_addr)
    ngx.req.set_header("X-3scale-debug", "")
    ngx.req.set_header("X-3scale-proxy-secret-token", var.secret_token)

    -- This is needed to call ngx.req.get_body_data() below.
    ngx.req.read_body()

    local request = {
        uri = uri,
        method = ngx.req.get_method(),
        headers = ngx.req.get_headers(0, true),
        path = format('%s%s%s', ngx.var.uri, ngx.var.is_args, ngx.var.query_string or ''),

        -- We cannot use resty.http's .get_client_body_reader().
        -- In POST requests with HTTPS, the result of that call is nil, and it
        -- results in a time-out.
        --
        --
        -- If ngx.req.get_body_data is nil, can be that the body is too big to
        -- read and need to be cached in a local file. This request will return
        -- nil, so after this we need to read the temp file.
        -- https://github.com/openresty/lua-nginx-module#ngxreqget_body_data
        body = ngx.req.get_body_data(),
        proxy_uri = proxy_uri,
        proxy_auth = proxy_auth
    }

    if not request.body then
        local temp_file_path = ngx.req.get_body_file()
        ngx.log(ngx.INFO, "HTTPS Proxy: Request body is bigger than client_body_buffer_size, read the content from path='", temp_file_path, "'")

        if temp_file_path then
          local body, err = file_reader(temp_file_path)
          if err then
            ngx.log(ngx.ERR, "HTTPS proxy: Failed to read temp body file, err: ", err)
            ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
          end
          request.body = body
        end
    end

    local httpc, err = http_proxy.new(request, skip_https_connect)

    if not httpc then
        ngx.log(ngx.ERR, 'could not connect to proxy: ',  proxy_uri, ' err: ', err)

        return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
    end

    local res
    res, err = httpc:request(request)

    if res then
        httpc:proxy_response(res)
        httpc:set_keepalive()
    else
        ngx.log(ngx.ERR, 'failed to proxy request to: ', proxy_uri, ' err : ', err)
        return ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end

local function get_proxy_uri(uri)
    local proxy_uri, err = http_proxy.find(uri)
    if not proxy_uri then return nil, err or 'invalid proxy url' end

    if not proxy_uri.port then
        proxy_uri.port = resty_url.default_port(proxy_uri.scheme)
    end

    return proxy_uri
end

function _M.find(upstream)
    return get_proxy_uri(upstream.uri)
end

function _M.request(upstream, proxy_uri)
    local uri = upstream.uri
    local proxy_auth

    if proxy_uri.user or proxy_uri.password then
        proxy_auth = "Basic " .. ngx.encode_base64(concat({ proxy_uri.user or '', proxy_uri.password or '' }, ':'))
    end

    if uri.scheme == 'http' then -- rewrite the request to use http_proxy
        -- Only set "Proxy-Authorization" when sending HTTP request. When sent over HTTPS,
        -- the `Proxy-Authorization` header must be sent in the CONNECT request as the proxy has
        -- no visibility into the tunneled request.
        --
        -- Also DO NOT set the header if using the camel proxy to avoid unintended leak of
        -- Proxy-Authorization header in requests
        if not ngx.var.http_proxy_authorization and proxy_auth and not upstream.skip_https_connect then
            ngx.req.set_header("Proxy-Authorization", proxy_auth)
        end

        local err
        local host = upstream:set_host_header()
        upstream:use_host_header(host)
        upstream.servers, err = resolve_servers(proxy_uri)
        if err then
          ngx.log(ngx.WARN, "HTTP proxy is set, but no servers have been resolved, err: ", err)
        end
        upstream.uri.path = absolute_url(uri)
        upstream:rewrite_request()
        return
    elseif uri.scheme == 'https' then
        upstream:rewrite_request()
        forward_https_request(proxy_uri, proxy_auth, uri, upstream.skip_https_connect)
        return ngx.exit(ngx.OK) -- terminate phase
    else
        ngx.log(ngx.ERR, 'could not connect to proxy: ',  proxy_uri, ' err: ', 'invalid request scheme')
        return ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end

return _M.reset()
