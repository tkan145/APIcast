-- This policy enables MTLS with the upstream API endpoint

local ssl = require('ngx.ssl')
local data_url = require('resty.data_url')
local util = require 'apicast.util'
local tls = require 'resty.tls'

local pairs = pairs

local X509_STORE = require('resty.openssl.x509.store')
local X509 = require('resty.openssl.x509')

local policy = require('apicast.policy')
local _M = policy.new('mtls', "builtin")

local path_type = "path"
local embedded_type = "embedded"

local new = _M.new

local function get_cert(value, value_type)

  if value_type == path_type then
    ngx.log(ngx.DEBUG, "reading path:", value)
    return util.read_file(value)
  end

  if value_type == embedded_type then
    local parsed_data, err = data_url.parse(value)
    if err then
      ngx.log(ngx.ERR, "Cannot parse certificate content: ", err)
      return nil
    end
    return parsed_data.data
  end
end

local function read_certificate(value, value_type)
  local data = get_cert(value, value_type)
  if data == nil then
    ngx.log(ngx.ERR, "Certificate value is invalid")
    return
  end
  return ssl.parse_pem_cert(data)
end

local function read_certificate_key(value, value_type)
  local data = get_cert(value, value_type)

  if data == nil then
    ngx.log(ngx.ERR, "Certificate key value is invalid")
    return
  end

  return ssl.parse_pem_priv_key(data)
end

local function read_ca_certificates(ca_certificates)
  local valid = false
  local store = X509_STORE.new()
  for _,certificate in pairs(ca_certificates) do
    local cert, err = X509.parse_pem_cert(certificate)
    if cert then
      valid = true
      store:add_cert(cert)
    else
      ngx.log(ngx.INFO, "cannot load certificate, err: ", err)
    end
  end

  if valid then
    return store.store
  end
end

function _M.new(config)
  local self = new(config)
  if config == nil then
    config = {}
  end

  self.cert = read_certificate(
    config.certificate,
    config.certificate_type or path_type)
  self.cert_key = read_certificate_key(
    config.certificate_key,
    config.certificate_key_type or path_type)
  self.ca_store = read_ca_certificates(config.ca_certificates or {})
  self.verify = config.verify

  return self
end

-- All of this happens on balancer because this is subrequest inside APICAst
--to @upstream, so the request need to be the one that connects to the
--upstream0
function _M:balancer(context)
  if self.cert and self.cert_key then
    self.set_certs(self.cert, self.cert_key)
  end

  if not self.verify then
    return
  end

  local ok, err = tls.set_upstream_ssl_verify(true, 1)
  if ok ~= nil then
    ngx.log(ngx.WARN, "Cannot verify SSL upstream connection, err: ", err)
  end

  if not self.ca_store then
    ngx.log(ngx.WARN, "Set verify without including CA certificates")
    return
  end

  self.set_ca_cert(self.ca_store)
end

return _M
