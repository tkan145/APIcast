local FAPIPolicy = require('apicast.policy.fapi')
local uuid = require('resty.jit-uuid')

describe('fapi_1_baseline_profile policy', function()
    local ngx_req_headers = {}
    local ngx_resp_headers = {}
    local context = {}
    before_each(function()
        ngx.header = {}
        ngx_req_headers = {}
        ngx_resp_headers = {}
        context = {}
        stub(ngx.req, 'get_headers', function() return ngx_req_headers end)
        stub(ngx.req, 'set_header', function(name, value) ngx_req_headers[name] = value end)
        stub(ngx.resp, 'get_headers', function() return ngx_resp_headers end)
        stub(ngx.resp, 'set_header', function(name, value) ngx_resp_headers[name] = value end)
        stub(ngx, 'print')
        stub(ngx, 'exit')
    end)

  describe('.new', function()
    it('works without configuration', function()
      assert(FAPIPolicy.new({}))
    end)
  end)

  describe('.header_filter', function()
    it('Use value from request', function()
        ngx_req_headers['x-fapi-transaction-id'] = 'abc'
        local transaction_id_policy = FAPIPolicy.new({})
        transaction_id_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('Only use x-fapi-transaction-id from request if the header also exist in response from upstream', function()
        ngx_req_headers['x-fapi-transaction-id'] = 'abc'
        ngx_resp_headers['x-fapi-transaction-id'] = 'bdf'
        local transaction_id_policy = FAPIPolicy.new({})
        transaction_id_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('Use x-fapi-transaction-id from upstream response', function()
        ngx_resp_headers['x-fapi-transaction-id'] = 'abc'
        local transaction_id_policy = FAPIPolicy.new({})
        transaction_id_policy:header_filter()
        assert.same('abc', ngx.header['x-fapi-transaction-id'])
    end)

    it('generate uuid if header does not exist in both request and response', function()
        local transaction_id_policy = FAPIPolicy.new({})
        transaction_id_policy:header_filter()
        assert.is_true(uuid.is_valid(ngx.header['x-fapi-transaction-id']))
    end)
  end)

  describe('x-fapi-customer-ip-address', function()
    it('Allow request with valid IPv4', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = '127.0.0.1'
        local transaction_id_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        transaction_id_policy:access()
        assert.stub(ngx.exit).was_not.called_with(403)
    end)

    it('Allow request with valid IPv6', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = '2001:db8::123:12:1'
        local transaction_id_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        transaction_id_policy:access()
        assert.stub(ngx.exit).was_not.called_with(403)
    end)

    it('Reject request if header contains more than 1 IP', function()
        ngx_req_headers['x-fapi-customer-ip-address'] = {"2001:db8::123:12:1", "127.0.0.1"}
        local transaction_id_policy = FAPIPolicy.new({validate_x_fapi_customer_ip_address=true})
        transaction_id_policy:access()
        assert.same(ngx.status, 403)
        assert.stub(ngx.print).was.called_with('{"error": "invalid_request"}')
        assert.stub(ngx.exit).was.called_with(403)
    end)
  end)
end)
