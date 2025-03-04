local user_agent = require "apicast.user_agent"
local http_ng = require "resty.http_ng"
local resty_env = require "resty.env"
local ngx_ssl = require "ngx.ssl"
local ocsp = require "ngx.ocsp"

local _M = {}
local ocsp_shm = ngx.shared.ocsp_cache

local function do_ocsp_request(ocsp_url, ocsp_request)
  -- TODO: set default timeout
  local http_client = http_ng.new{
    options = {
      headers = {
        ['User-Agent'] = user_agent()
      },
      ssl = { verify = resty_env.enabled('OPENSSL_VERIFY') }
    }
  }
  local res, err = http_client.post{
    ocsp_url,
    ocsp_request,
    headers= {
      ["Content-Type"] = "application/ocsp-request"
  }}
  if err then
    return nil, err
  end

  ngx.log(ngx.INFO, "fetching OCSP response from ", ocsp_url)

  if not res then
    return nil, "failed to send request to OCSP responder: " .. tostring(err)
  end

  if res.status ~= 200 then
    return nil, "unexpected OCSP responder status code: " .. res.status
  end

  return res.body
end

function _M.check_revocation_status(cert_chain, ocsp_responder_url, digest, ttl)
  if not cert_chain then
    return false, "invalid client certificate chain"
  end

  local der_cert, err = ngx_ssl.cert_pem_to_der(cert_chain)
  if not der_cert then
    return nil, "failed to convert certificate chain from PEM to DER " ..  err
  end

  local ocsp_resp
  ocsp_resp = ocsp_shm:get(digest)

  if ocsp_resp == nil then
    ngx.log(ngx.INFO, "no ocsp resp cache found, fetch from ocsp responder")


    -- TODO: check response cache
    local ocsp_url
    if ocsp_responder_url and ocsp_responder_url ~= "" then
      ocsp_url = ocsp_responder_url
    else
      ocsp_url, err = ocsp.get_ocsp_responder_from_der_chain(der_cert)
      if not ocsp_url then
        return nil, err or ("could not extract OCSP responder URL, the client " ..
                              "certificate may be missing the required extensions")
      end
    end

    if not ocsp_url or ocsp_url == "" then
      return nil, " invalid OCSP responder URL"
    end

    local ocsp_req
    ocsp_req, err = ocsp.create_ocsp_request(der_cert)
    if not ocsp_req then
      return nil, "failed to create OCSP request: " .. err
    end

    ocsp_resp, err = do_ocsp_request(ocsp_url, ocsp_req)
    if not ocsp_resp or #ocsp_resp == 0 then
      return nil, "unexpected response from OCSP responder: empty body"
    end

    -- Use ttl, normally this should be (nextUpdate - thisUpdate), but current version
    -- of openresty API does not expose those attributes. Support for this was added
    -- in openrest-core v0.1.31, we either need to backport or upgrade the openresty
    -- version.
    local ok
    ok, err = ocsp_shm:set(digest, ocsp_resp, ttl)
    if not ok then
      ngx.log(ngx.ERR, "could not save ocsp response to cache: ", err)
    end
  end

  local ok
  ok, err = ocsp.validate_ocsp_response(ocsp_resp, der_cert)
  if not ok then
    return false, "failed to validate OCSP response: " .. err
  end

  return true
end

return _M
