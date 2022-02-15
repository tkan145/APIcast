local ClearContextPolicy = require('apicast.policy.clear_context')
local ngx_variable = require('apicast.policy.ngx_variable')
   

describe('Clear Context policy', function()
  local current_ctx = {some_key = 'some_value'}

  describe('.ssl_certificate + .rewrite', function()
    before_each(function()
      ctx = {}
      stub(ngx_variable, 'available_context', function(context) return context end)
    end)

    context('.ssl_certificate', function()
      local clear_context_policy = ClearContextPolicy.new()

      it('clears the context', function()
        ctx.current = current_ctx
        clear_context_policy:ssl_certificate(ctx)
        assert.are.same({}, ctx.current)
      end)
    end)

    context('.rewrite', function()
      local clear_context_policy = ClearContextPolicy.new()
  
      it('clears the context', function()
        ctx.current = current_ctx
        clear_context_policy:rewrite(ctx)
        assert.are.same({}, ctx.current)
      end)
    end)

    context('.ssl_certificate and .rewrite', function()
      local clear_context_policy = ClearContextPolicy.new()
      
      it('clears the context once', function()
        ctx.current = current_ctx
        clear_context_policy:ssl_certificate(ctx)
        assert.are.same({}, ctx.current)
        ctx.current = current_ctx
        clear_context_policy:rewrite(ctx)
        assert.are.same(current_ctx, ctx.current)
      end)
    end)

    context('.ssl_certificate and .ssl_certificate', function()
      local clear_context_policy = ClearContextPolicy.new()
      
      it('clears the context twice', function()
        ctx.current = current_ctx
        clear_context_policy:ssl_certificate(ctx)
        assert.are.same({}, ctx.current)
        ctx.current = current_ctx
        clear_context_policy:ssl_certificate(ctx)
        assert.are.same({}, ctx.current)
      end)
    end)

    context('.rewrite and .rewrite', function()
      local clear_context_policy = ClearContextPolicy.new()
      
      it('clears the context twice', function()
        ctx.current = current_ctx
        clear_context_policy:rewrite(ctx)
        assert.are.same({}, ctx.current)
        ctx.current = current_ctx
        clear_context_policy:rewrite(ctx)
        assert.are.same({}, ctx.current)
      end)
    end)
  end)
end)


