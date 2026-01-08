--- Policy Manifest Cache
-- Provides module-level caching for policy manifests.

local format = string.format

local _M = {}

-- Module-level cache storage (one per worker process)
local manifest_cache = {}

-- Cache key builders
local function manifest_key(name, version)
  return format("%s:%s", name, version)
end

--- Get a cached manifest by policy name and version
-- @tparam string name The policy name
-- @tparam string version The policy version (or 'builtin')
-- @treturn table|nil The cached manifest table, or nil if not cached
function _M.get_manifest(name, version)
  local key = manifest_key(name, version)
  return manifest_cache[key]
end

--- Store a manifest in the cache
-- @tparam string name The policy name
-- @tparam string version The policy version (or 'builtin')
-- @tparam table manifest The decoded manifest table to cache
function _M.set_manifest(name, version, manifest)
  local key = manifest_key(name, version)
  manifest_cache[key] = manifest
  ngx.log(ngx.DEBUG, 'cached manifest: ', key)
end

local LOCAL_POLICIES = {
    'load_configuration',
    'find_service',
    'local_chain',
    'nginx_metrics',
    'clear_context',
    'standalone',
    'management',
    'phase_logger',
    'conditional'
}

function _M.warmup_cache()
    local list = LOCAL_POLICIES or { 'apicast.policy.apicast' }

    for i=1, #list do
      _M.set_manifest(list[i], 'builtin', {})
    end
end

return _M

