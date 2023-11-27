local format = string.format
local tostring = tostring
local ngx_flush = ngx.flush
local ngx_get_method = ngx.req.get_method
local ngx_http_version = ngx.req.http_version
local ngx_send_headers = ngx.send_headers

local resty_url = require "resty.url"
local resty_resolver = require 'resty.resolver'
local round_robin = require 'resty.balancer.round_robin'
local http_proxy = require 'resty.http.proxy'
local file_reader = require("resty.file").file_reader
local file_size = require("resty.file").file_size
local client_body_reader = require("resty.http.request_reader").get_client_body_reader
local send_response = require("resty.http.response_writer").send_response
local concat = table.concat

local _M = { }

local http_methods_with_body = {
  POST = true,
  PUT = true,
  PATCH = true
}

local DEFAULT_CHUNKSIZE = 32 * 1024

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

local function handle_expect()
    local expect = ngx.req.get_headers()["Expect"]
    if type(expect) == "table" then
        expect = expect[1]
    end

    if expect and expect:lower() == "100-continue" then
        ngx.status = 100
        local ok, err = ngx_send_headers()

        if not ok then
            return nil, "failed to send response header: " .. (err or "unknown")
        end

        ok, err = ngx_flush(true)
        if not ok then
            return nil, "failed to flush response header: " .. (err or "unknown")
        end
    end
end

local function forward_https_request(proxy_uri, uri, proxy_opts)
    local body, err
    local sock
    local opts = proxy_opts or {}
    local req_method = ngx_get_method()
    local encoding = ngx.req.get_headers()["Transfer-Encoding"]
    local is_chunked = encoding and encoding:lower() == "chunked"

    if http_methods_with_body[req_method] then
      if opts.request_unbuffered and ngx_http_version() == 1.1 then
        local _, err = handle_expect()
        if err then
            ngx.log(ngx.ERR, "failed to handle expect header, err: ", err)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        if is_chunked then
            -- The default ngx reader does not support chunked request
            -- so we will need to get the raw request socket and manually
            -- decode the chunked request
            sock, err = ngx.req.socket(true)
        else
            sock, err = ngx.req.socket()
        end

        if not sock then
            ngx.log(ngx.ERR, "unable to obtain request socket: ", err)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        body = client_body_reader(sock, DEFAULT_CHUNKSIZE, is_chunked)
      else
        -- This is needed to call ngx.req.get_body_data() below.
        ngx.req.read_body()

        -- We cannot use resty.http's .get_client_body_reader().
        -- In POST requests with HTTPS, the result of that call is nil, and it
        -- results in a time-out.
        --
        --
        -- If ngx.req.get_body_data is nil, can be that the body is too big to
        -- read and need to be cached in a local file. This request will return
        -- nil, so after this we need to read the temp file.
        -- https://github.com/openresty/lua-nginx-module#ngxreqget_body_data
        body = ngx.req.get_body_data()

        if not body then
            local temp_file_path = ngx.req.get_body_file()
            ngx.log(ngx.INFO, "HTTPS Proxy: Request body is bigger than client_body_buffer_size, read the content from path='", temp_file_path, "'")

            if temp_file_path then
              body, err = file_reader(temp_file_path)
              if err then
                ngx.log(ngx.ERR, "HTTPS proxy: Failed to read temp body file, err: ", err)
                ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
              end

              if is_chunked then
                -- If the body is smaller than "client_boby_buffer_size" the Content-Length header is
                -- set based on the size of the buffer. However, when the body is rendered to a file,
                -- we will need to calculate and manually set the Content-Length header based on the
                -- file size
                local contentLength, err = file_size(temp_file_path)
                if err then
                    ngx.log(ngx.ERR, "HTTPS proxy: Failed to set content length, err: ", err)
                    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                end

                ngx.req.set_header("Content-Length", tostring(contentLength))
              end
            end
        end

        -- The whole request is buffered in the memory so remove the Transfer-Encoding: chunked
        if is_chunked then
            ngx.req.set_header("Transfer-Encoding", nil)
        end
      end
    end

    local request = {
        uri = uri,
        method = ngx.req.get_method(),
        headers = ngx.req.get_headers(0, true),
        path = format('%s%s%s', ngx.var.uri, ngx.var.is_args, ngx.var.query_string or ''),
        body = body,
        proxy_uri = proxy_uri,
        proxy_auth = opts.proxy_auth
    }

    local httpc, err = http_proxy.new(request, opts.skip_https_connect)

    if not httpc then
        ngx.log(ngx.ERR, 'could not connect to proxy: ',  proxy_uri, ' err: ', err)

        return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
    end

    local res
    res, err = httpc:request(request)

    if res then
        if opts.request_unbuffered and is_chunked then
            local bytes, err = send_response(sock, res, DEFAULT_CHUNKSIZE)
            if not bytes then
                ngx.log(ngx.ERR, "failed to send response: ", err)
                return sock:send("HTTP/1.1 502 Bad Gateway")
            end
        else
            httpc:proxy_response(res)
            httpc:set_keepalive()
        end
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
        local proxy_opts = {
            proxy_auth = proxy_auth,
            skip_https_connect = upstream.skip_https_connect,
            request_unbuffered = upstream.request_unbuffered
        }

        forward_https_request(proxy_uri, uri, proxy_opts)
        return ngx.exit(ngx.OK) -- terminate phase
    else
        ngx.log(ngx.ERR, 'could not connect to proxy: ',  proxy_uri, ' err: ', 'invalid request scheme')
        return ngx.exit(ngx.HTTP_BAD_GATEWAY)
    end
end

return _M.reset()
