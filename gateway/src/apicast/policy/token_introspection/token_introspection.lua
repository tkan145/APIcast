local policy = require('apicast.policy')
local _M = policy.new('Token Introspection Policy')

local cjson = require('cjson.safe')
local http_authorization = require 'resty.http_authorization'
local http_ng = require 'resty.http_ng'
local user_agent = require 'apicast.user_agent'
local resty_env = require('resty.env')
local resty_url = require('resty.url')

local tokens_cache = require('tokens_cache')

local tonumber = tonumber

local new = _M.new

local noop = function() end
local noop_cache = { get = noop, set = noop }

local function create_credential(client_id, client_secret)
  return 'Basic ' .. ngx.encode_base64(table.concat({ client_id, client_secret }, ':'))
end

function _M.new(config)
  local self = new(config)
  self.config = config or {}
  self.auth_type = config.auth_type or "client_id+client_secret"
  --- authorization for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.2
  if self.auth_type == "client_id+client_secret" then
    self.client_id = self.config.client_id or ''
    self.client_secret = self.config.client_secret or ''
    self.introspection_url = config.introspection_url
  end
  self.http_client = http_ng.new{
    backend = config.client,
    options = {
      headers = {
        ['User-Agent'] = user_agent()
      },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }

  local max_cached_tokens = tonumber(config.max_cached_tokens) or 0
  self.caching_enabled = max_cached_tokens > 0

  if self.caching_enabled then
    self.tokens_cache = tokens_cache.new(
      config.max_ttl_tokens, config.max_cached_tokens)
  else
    self.tokens_cache = noop_cache
  end

  return self
end

--- OAuth 2.0 Token Introspection defined in RFC7662.
-- https://tools.ietf.org/html/rfc7662
local function introspect_token(self, token)
  local cached_token_info = self.tokens_cache:get(token)
  if cached_token_info then return cached_token_info end

  local headers = {}
  if self.client_id and self.client_secret then
    headers['Authorization'] = create_credential(self.client_id or '', self.client_secret or '')
  end

  --- Parameters for the token introspection endpoint.
  -- https://tools.ietf.org/html/rfc7662#section-2.1
  local res, err = self.http_client.post{self.introspection_url , { token = token, token_type_hint = 'access_token'},
    headers = headers}
  if err then
    ngx.log(ngx.WARN, 'token introspection error: ', err, ' url: ', self.introspection_url)
    return { active = false }
  end

  if res.status == 200 then
    local token_info, decode_err = cjson.decode(res.body)
    if type(token_info) == 'table' then
      self.tokens_cache:set(token, token_info)
      return token_info
    else
      ngx.log(ngx.ERR, 'failed to parse token introspection response:', decode_err)
      return { active = false }
    end
  else
    ngx.log(ngx.WARN, 'failed to execute token introspection. status: ', res.status)
    return { active = false }
  end
end

function _M:access(context)
  if self.auth_type == "use_3scale_oidc_issuer_endpoint" then
    if not context.proxy.oauth then
      ngx.status = context.service.auth_failed_status
      ngx.say(context.service.error_auth_failed)
      return ngx.exit(ngx.status)
    end

    local components = resty_url.parse(context.service.oidc.issuer_endpoint)
    self.client_id = components.user
    self.client_secret = components.password
    local oauth_config = context.proxy.oauth.config
    -- token_introspection_endpoint being deprecated in RH SSO 7.4 and removed in 7.5
    -- https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.5/html-single/upgrading_guide/index#non_standard_token_introspection_endpoint_removed
    self.introspection_url = oauth_config.introspection_endpoint or oauth_config.token_introspection_endpoint
  end

  if self.introspection_url then
    local authorization = http_authorization.new(ngx.var.http_authorization)
    local access_token = authorization.token
    --- Introspection Response must have an "active" boolean value.
    -- https://tools.ietf.org/html/rfc7662#section-2.2
    if introspect_token(self, access_token).active == true then
      -- access granted
      return
    end

    ngx.log(ngx.INFO, 'token introspection for access token ', access_token, ': token not active')
  else
    ngx.log(ngx.WARN, 'token instropection cannot be performed as introspection endpoint is not available')
  end

  ngx.status = context.service.auth_failed_status
  ngx.say(context.service.error_auth_failed)
  return ngx.exit(ngx.status)
end

return _M
