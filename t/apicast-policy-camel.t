use lib 't';
use Test::APIcast::Blackbox 'no_plan';

require("http_proxy.pl");

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: API backend connection uses http proxy 
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      local assert = require('luassert')
      assert.equals(result, "test-upstream.lvh.me:")
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY

=== TEST 2: API backend using all_proxy
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      local host = ngx.req.get_headers()["Host"]
      local result = string.match(host, "^test%-upstream%.lvh%.me:")
      local assert = require('luassert')
      assert.equals(result, "test-upstream.lvh.me:")
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY

=== TEST 3: using HTTPS proxy for backend.
--- init eval
$Test::Nginx::Util::PROXY_SSL_PORT = Test::APIcast::get_random_port();
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- configuration random_port env eval
<<EOF
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://localhost:$Test::Nginx::Util::ENDPOINT_SSL_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "https_proxy": "http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT"
            }
          }
        ]
      }
    }
  ]
}
EOF
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream eval
<<EOF
  # Endpoint config
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;

  server_name _ default_server;

  location /test {
    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$Test::Nginx::Util::ENDPOINT_SSL_PORT', ngx.var.server_port)
      assert.equal('localhost', ngx.var.ssl_server_name)
      assert.equal(ngx.var.request_uri, '/test?user_key=test3')

      local host = ngx.req.get_headers()["Host"]
      assert.equal(host, 'localhost:$Test::Nginx::Util::ENDPOINT_SSL_PORT')
      ngx.say("yay, endpoint backend")

    }
  }
}
server {
  # Proxy config
  listen $Test::Nginx::Util::PROXY_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;


  server_name _ default_server;

  location ~ /.* {
    proxy_http_version 1.1;
    proxy_pass https://\$http_host;
  }
EOF
--- request
GET /test?user_key=test3
--- more_headers
User-Agent: Test::APIcast::Blackbox
ETag: foobar
--- error_code: 200
--- user_files fixture=tls.pl eval
--- error_log eval
<<EOF
using proxy: http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT,
EOF

=== TEST 4: using HTTPS proxy without api_backend upstream
--- init eval
$Test::Nginx::Util::PROXY_SSL_PORT = Test::APIcast::get_random_port();
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- configuration random_port env eval
<<EOF
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.routing",
            "configuration": {
              "rules": [
                {
                  "url": "https://localhost:$Test::Nginx::Util::ENDPOINT_SSL_PORT",
                  "condition": {
                    "operations": [
                      {
                        "match": "liquid",
                        "liquid_value": "test",
                        "op": "==",
                        "value": "test"
                      }
                    ]
                  }
                }
              ]
            }
          },
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "https_proxy": "http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT"
            }
          }
        ]
      }
    }
  ]
}
EOF
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream eval
<<EOF
  # Endpoint config
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;

  server_name _ default_server;

  location /test {
    access_by_lua_block {
      assert = require('luassert')
      assert.equal('https', ngx.var.scheme)
      assert.equal('$Test::Nginx::Util::ENDPOINT_SSL_PORT', ngx.var.server_port)
      assert.equal('localhost', ngx.var.ssl_server_name)
      assert.equal(ngx.var.request_uri, '/test?user_key=test3')

      local host = ngx.req.get_headers()["Host"]
      assert.equal(host, 'localhost:$Test::Nginx::Util::ENDPOINT_SSL_PORT')
      ngx.say("yay, endpoint backend")

    }
  }
}
server {
  # Proxy config
  listen $Test::Nginx::Util::PROXY_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;


  server_name _ default_server;

  location ~ /.* {
    proxy_http_version 1.1;
    proxy_pass https://\$http_host;
  }
EOF
--- request
GET /test?user_key=test3
--- more_headers
User-Agent: Test::APIcast::Blackbox
ETag: foobar
--- error_code: 200
--- user_files fixture=tls.pl eval
--- error_log eval
<<EOF
using proxy: http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT,
EOF


=== TEST 5: API backend connection uses http proxy with Basic Auth
Check that the Proxy Authorization header is not sent
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "http_proxy": "http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local proxy_auth = ngx.req.get_headers()['Proxy-Authorization']
      assert.falsy(proxy_auth)
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT

=== TEST 6: API backend using all_proxy with Basic Auth
Check that the Proxy Authorization header is not sent
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "all_proxy": "http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local proxy_auth = ngx.req.get_headers()['Proxy-Authorization']
      assert.falsy(proxy_auth)
      ngx.say("yay, api backend")
    }
  }
--- request
GET /?user_key=value
--- response_body
yay, api backend
--- error_code: 200
--- error_log env
using proxy: http://foo:bar@127.0.0.1:$TEST_NGINX_HTTP_PROXY_PORT


=== TEST 7: using HTTPS proxy for backend with Basic Auth.
Check that the Proxy Authorization header is not sent
--- init eval
$Test::Nginx::Util::PROXY_SSL_PORT = Test::APIcast::get_random_port();
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- configuration random_port env eval
<<EOF
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://127.0.0.1:$Test::Nginx::Util::ENDPOINT_SSL_PORT",
        "proxy_rules": [
          { "pattern": "/test", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "https_proxy": "http://foo:bar\@127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT"
            }
          }
        ]
      }
    }
  ]
}
EOF
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream eval
<<EOF
  # Endpoint config
  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;

  server_name _ default_server;

  location /test {
    access_by_lua_block {
      ngx.say("yay, endpoint backend")

    }
  }
}
server {
  # Proxy config
  listen $Test::Nginx::Util::PROXY_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;


  server_name _ default_server;

  location ~ /.* {
    proxy_http_version 1.1;
    proxy_pass https://\$http_host;
  }
EOF
--- request
GET /test?user_key=test3
--- error_code: 200
--- user_files fixture=tls.pl eval
--- error_log eval
<<EOF
using proxy: http://foo:bar\@127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT,
EOF
--- no_error_log eval
[qr/\[error\]/, qr/\got header line: Proxy-Authorization: Basic Zm9vOmJhcg==/]



=== TEST 8: API backend connection uses http proxy with chunked request
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "http_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo $request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body
hello, world
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]



=== TEST 9: API backend using all_proxy with chunked request
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test-upstream.lvh.me:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.http_proxy",
            "configuration": {
                "all_proxy": "$TEST_NGINX_HTTP_PROXY"
            }
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local expected = "service_token=token-value&service_id=42&usage%5Bhits%5D=2&user_key=value"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- upstream
  server_name test-upstream.lvh.me;
  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo $request_body;
  }
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body
hello, world
--- error_code: 200
--- error_log env
using proxy: $TEST_NGINX_HTTP_PROXY
--- no_error_log
[error]



=== TEST 10: using HTTPS proxy for backend with chunked request
--- init eval
$Test::Nginx::Util::PROXY_SSL_PORT = Test::APIcast::get_random_port();
$Test::Nginx::Util::ENDPOINT_SSL_PORT = Test::APIcast::get_random_port();
--- configuration random_port env eval
<<EOF
{
  "services": [
    {
      "backend_version":  1,
      "proxy": {
        "api_backend": "https://test-upstream.lvh.me:$Test::Nginx::Util::ENDPOINT_SSL_PORT",
        "proxy_rules": [
          { "pattern": "/", "http_method": "POST", "metric_system_name": "hits", "delta": 2 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.apicast"
          },
          {
            "name": "apicast.policy.camel",
            "configuration": {
                "https_proxy": "http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT"
            }
          }
        ]
      }
    }
  ]
}
EOF
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(ngx.OK)
    }
  }
--- upstream eval
<<EOF
  # Endpoint config
  server_name test-upstream.lvh.me;

  listen $Test::Nginx::Util::ENDPOINT_SSL_PORT ssl;
  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;

  location / {
    access_by_lua_block {
      assert = require('luassert')
      local content_length = ngx.req.get_headers()["Content-Length"]
      local encoding = ngx.req.get_headers()["Transfer-Encoding"]
      assert.equal('12', content_length)
      assert.falsy(encoding)
    }
    echo_read_request_body;
    echo_request_body;
  }
}
server {
  # Proxy config
  listen $Test::Nginx::Util::PROXY_SSL_PORT ssl;

  ssl_certificate $Test::Nginx::Util::ServRoot/html/server.crt;
  ssl_certificate_key $Test::Nginx::Util::ServRoot/html/server.key;


  server_name _ default_server;

  location ~ /.* {
    proxy_http_version 1.1;
    proxy_pass https://\$http_host;
  }
EOF
--- more_headers
Transfer-Encoding: chunked
--- request eval
"POST /?user_key=value
7\r
hello, \r
5\r
world\r
0\r
\r
"
--- response_body chomp
hello, world
--- error_code: 200
--- error_log eval
<<EOF
using proxy: http://127.0.0.1:$Test::Nginx::Util::PROXY_SSL_PORT,
EOF
--- no_error_log
[error]
--- user_files fixture=tls.pl eval
