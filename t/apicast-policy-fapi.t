use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Test::Nginx does not allow to grep access logs, so we redirect them to
# stderr to be able to use "grep_error_log" by setting APICAST_ACCESS_LOG_FILE

run_tests();

__DATA__

=== TEST 1: Enables fapi policy inject x-fapi-transaction-id header to the response
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi", "configuration": {}
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
        ngx.exit(200)
     }
  }
--- more_headers
x-fapi-transaction-id: abc
--- response_headers
x-fapi-transaction-id: abc
--- request
GET /?user_key=value
--- error_code: 200
--- no_error_log
[error]



=== TEST 2: When x-fapi-transaction-id exist in both request and response headers, always use
value from request
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi"
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       ngx.header['x-fapi-transaction-id'] = "blah"
       ngx.exit(200)
     }
  }
--- more_headers
x-fapi-transaction-id: abc
--- request
GET /?user_key=value
--- response_headers
x-fapi-transaction-id: abc
--- error_code: 200
--- no_error_log
[error]



=== TEST 3: Use x-fapi-transaction-id header from upstream response
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi"
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
        ngx.exit(200)
    }
  }
--- upstream
  location / {
     content_by_lua_block {
       ngx.header['x-fapi-transaction-id'] = "blah"
       ngx.exit(200)
     }
  }
--- request
GET /?user_key=value
--- response_headers
x-fapi-transaction-id: blah
--- error_code: 200
--- no_error_log
[error]



=== TEST 4: inject uuid to the response header
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 1 }
        ],
        "policy_chain": [
          {
            "name": "apicast.policy.fapi"
          },
          {
            "name": "apicast.policy.apicast"
          }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- request
GET /?user_key=value
--- response_headers_like
x-fapi-transaction-id: [0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$
--- error_code: 200
--- no_error_log
[error]
