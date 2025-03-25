local custom_metrics =  require("apicast.policy.custom_metrics")
local ngx_variable = require 'apicast.policy.ngx_variable'
local Usage = require('apicast.usage')


describe('custom metrics policy', function()
  local context = {}
  local usage = {}

  before_each(function()
    ngx.var = {}
    ngx.header = {}

    stub(ngx_variable, 'available_context', function(ctx) return ctx end)
    stub(ngx.req, 'get_headers', function() return {} end)
    stub(ngx.resp, 'get_headers', function() return {} end)

    context = { usage = {} }
    stub(context.usage, 'merge', function() return end)

    usage = Usage.new()
    usage:add("foo", 1)
  end)

  describe('if Auth cache is disabled', function()
    it('reports the usage', function()
      local config = {
        rules = {
          {
            metric = "foo",
            increment = "1",
            condition = {
              combine_op = "and",
              operations = {
                { left = "foo", op = "==", right = "foo" }
              }
            }
          }
        }
      }

      local policy = custom_metrics.new(config)

      stub(policy, "report", function(_, _) return end)

      policy:post_action(context)
      assert.spy(policy.report).was_called()
      assert.spy(policy.report).was.called_with(context, usage)
    end)
  end)

  describe('if Auth cache is enabled', function()
    it('usage is incremented', function()
      ngx.var.cached_key = true

      local config = {
        rules = {
          {
            metric = "foo",
            increment = "1",
            condition = {
              combine_op = "and",
              operations = {
                { left = "foo", op = "==", right = "foo" }
              }
            }
          }
        }
      }

      local policy = custom_metrics.new(config)

      stub(policy, "report", function(_, _) return end)
      policy:post_action(context)
      assert.spy(policy.report).was_not_called()
      assert.spy(context.usage.merge).was_called()

      assert.spy(context.usage.merge).was_called_with(context.usage, usage)
    end)
  end)

  describe('.report', function()
    local config
    local backend_client = require('apicast.backend_client')

    before_each(function()
      config = {
        rules = {
          {
            metric = "foo",
            increment = "1",
            condition = {
              combine_op = "and",
              operations = {
                { left = "foo", op = "==", right = "foo" }
              }
            }
          }
        }
      }
    end)

    it('is not called with invalid backend endpoint', function()
      -- By default return a hit in the caches to simplify tests
      stub(backend_client, "report")

      local policy = custom_metrics.new(config)

      context.service = {backend = {endpoint="invalid.com"}, id="42"}
      policy:post_action(context)
      assert.spy(backend_client.report).was_not_called()
    end)

    it('to backend', function()
      -- By default return a hit in the caches to simplify tests
      stub(backend_client, 'report').returns({ status = 200 })

      local policy = custom_metrics.new(config)

      context = {
        service = {
          backend = {endpoint="http://foo.com"},
          id="42"
        },
        credentials={app_id = 'id1', metric = 'm1', value = 1 },
      }
      policy:post_action(context)
      assert.spy(backend_client.report).was_called()
    end)
  end)
end)
