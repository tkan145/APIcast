use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: load configuration with APICAST_SERVICE_${ID}_CONFIGURATION_VERSION
--- env eval
(
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}",
  'APICAST_SERVICE_2_CONFIGURATION_VERSION' => 42
)
--- upstream env
    location = /admin/api/services.json {
        echo '{ "services": [ { "service": { "id": 2 } } ] }';
    }
    location = /admin/api/services/2/proxy/configs/production/42.json {
        echo '
        {
            "proxy_config": {
                "content": {
                    "id": 2,
                    "backend_version": 1,
                    "proxy": {
                        "hosts": [ "localhost" ],
                        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
                        "proxy_rules": [
                            { "pattern": "/t", "http_method": "GET", "metric_system_name": "test","delta": 1 }
                        ]
                    }
                }
            }
        }';
    }

    location /t {
        echo "all ok";
    }

--- backend
    location /transactions/authrep.xml {
      content_by_lua_block {
        ngx.exit(200)
      }
    }
--- request
GET /t?user_key=fake
--- error_code: 200
--- error_log
using lazy configuration loader
--- no_error_log
[error]

=== TEST 2: load configuration with APICAST_SERVICE_${ID}_CONFIGURATION_VERSION with paginated service list
and paginated service list. This test is configured to provide 3 pages of services.
On each page, there is one service for which the version will be overriden.
The test will do one request to each valid service.
--- env eval
(
  'APICAST_SERVICE_1_CONFIGURATION_VERSION' => 42,
  'APICAST_SERVICE_500_CONFIGURATION_VERSION' => 42,
  'APICAST_SERVICE_1000_CONFIGURATION_VERSION' => 42,
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location = /admin/api/services.json {
  content_by_lua_block {
    local args = ngx.req.get_uri_args(0)
    local page = 1
    if args.page then
      page = tonumber(args.page)
    end
    local per_page = 500
    if args.per_page then
      per_page = tonumber(args.per_page)
    end

    local services_per_page = {}
    for i = (page - 1)*per_page + 1,math.min(page*per_page, 1256)
    do
      table.insert(services_per_page, {service = { id = i }})
    end

    require('luassert').True(#services_per_page <= per_page)

    local response = { services = services_per_page }
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode(response))
  }
}

location ~ /admin/api/services/\d+/proxy/configs/production/.*.json {
  content_by_lua_block {
    local proxy_config = {
      content = { id = 1, backend_version = 1,
        proxy = {
          hosts = { 'other' },
          api_backend = 'http://test:$TEST_NGINX_SERVER_PORT/api/',
          backend = { endpoint = 'http://test:$TEST_NGINX_SERVER_PORT' },
          proxy_rules = { { pattern = '/', http_method = 'GET', metric_system_name = 'test', delta = 1 } }
        }
      }
    }

    if( ngx.var.uri == '/admin/api/services/1/proxy/configs/production/42.json' )
    then
      proxy_config.content.id = 1
      proxy_config.content.proxy.hosts = { 'one-1' }
    elseif( ngx.var.uri == '/admin/api/services/500/proxy/configs/production/42.json'  )
    then
      proxy_config.content.id = 500
      proxy_config.content.proxy.hosts = { 'one-500' }
    elseif( ngx.var.uri == '/admin/api/services/1000/proxy/configs/production/42.json'  )
    then
      proxy_config.content.id = 1000
      proxy_config.content.proxy.hosts = { 'one-1000' }
    end

    local response = { proxy_config = proxy_config }
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode(response))
  }
}

location /api/ {
  echo 'yay, api backend';
}

--- backend
location /transactions/authrep.xml {
  content_by_lua_block { ngx.exit(200) }
}

--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=1","GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one-1","Host: one-500","Host: one-1000","Host: two"]
--- response_body eval
["yay, api backend\n","yay, api backend\n","yay, api backend\n",""]
--- error_code eval
[200, 200, 200, 404]
