use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: multi service configuration limited with Regexp Filter
--- env eval
("APICAST_SERVICES_FILTER_BY_URL", "^on*")
--- configuration
{
  "services": [
    {
      "backend_version": 1,
      "proxy": {
        "hosts": [
          "one"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          {
            "http_method": "GET",
            "delta": 1,
            "metric_system_name": "one",
            "pattern": "/"
          }
        ]
      },
      "id": 42
    },
    {
      "proxy": {
        "hosts": [
          "two"
        ]
      },
      "id": 11
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block { ngx.exit(200) }
  }
--- upstream
  location ~ / {
     echo 'yay, api backend';
  }
--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=2"]
--- more_headers eval
["Host: one", "Host: two"]
--- response_body eval
["yay, api backend\n", ""]
--- error_code eval
[200, 404]

=== TEST 2: multi service configuration limited with Regexp Filter with paginated service list
This test is configured to provide 3 pages of services. On each page, there is one service "one-*"
which is valid according to the filter by url. The test will do one request to each valid service.
--- env eval
(
  'APICAST_SERVICES_FILTER_BY_URL' => "^one*",
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

location ~ /admin/api/services/\d+/proxy/configs/production/latest.json {
  content_by_lua_block {
    local proxy_config = {
      content = { id = 1, backend_version = 1,
        proxy = {
          hosts = { 'two' },
          api_backend = 'http://test:$TEST_NGINX_SERVER_PORT/api/',
          backend = { endpoint = 'http://test:$TEST_NGINX_SERVER_PORT' },
          proxy_rules = { { pattern = '/', http_method = 'GET', metric_system_name = 'test', delta = 1 } }
        }
      }
    }

    if( ngx.var.uri == '/admin/api/services/1/proxy/configs/production/latest.json' )
    then
      proxy_config.content.id = 1
      proxy_config.content.proxy.hosts = { 'one-1' }
    elseif( ngx.var.uri == '/admin/api/services/500/proxy/configs/production/latest.json'  )
    then
      proxy_config.content.id = 500
      proxy_config.content.proxy.hosts = { 'one-500' }
    elseif( ngx.var.uri == '/admin/api/services/1000/proxy/configs/production/latest.json'  )
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
