use Test::APIcast::Blackbox 'no_plan';

our $private_key = `cat t/fixtures/rsa.pem`;
our $public_key = `cat t/fixtures/rsa.pub`;

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: multi service configuration limited to specific service
--- env eval
("APICAST_SERVICES_LIST", "42,21")
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

=== TEST 2: multi service configuration limited with Regexp Filter and service list
--- env eval
(
"APICAST_SERVICES_FILTER_BY_URL", "^on*",
"APICAST_SERVICES_LIST", "21"
)
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
      "backend_version": 1,
      "proxy": {
        "hosts": [
          "two"
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/two",
        "proxy_rules": [
          {
            "http_method": "GET",
            "delta": 1,
            "metric_system_name": "one",
            "pattern": "/"
          }
        ]
      },
      "id": 21
    },
    {
      "proxy": {
        "hosts": [
          "three"
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
  location / {
     echo 'yay, api backend';
  }

  location /two {
     echo 'yay, api backend two';
  }

--- pipelined_requests eval
["GET /?user_key=1","GET /?user_key=2", "GET /?user_key=3"]
--- more_headers eval
["Host: one", "Host: two", "Host: three"]
--- response_body eval
["yay, api backend\n", "yay, api backend two\n", ""]
--- error_code eval
[200, 200, 404]


=== TEST 3: Verify that OIDC is working when filter services.
Related to issues THREESCALE-6042
--- env eval
(
  "APICAST_SERVICES_LIST", "42"
)
--- configuration env eval
use JSON qw(to_json);

to_json({
  services => [
  {
    id => 12,
    backend_version => '1',
    proxy => {
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["null.com"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  },
  {
    id => 24,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    backend_authentication_value => 'fookey',
    proxy => {
        authentication_method => 'oidc',
        oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast_zero',
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["zero"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  },
  {
    id => 42,
    backend_version => 'oauth',
    backend_authentication_type => 'provider_key',
    backend_authentication_value => 'fookey',
    proxy => {
        authentication_method => 'oidc',
        oidc_issuer_endpoint => 'https://example.com/auth/realms/apicast_one',
        api_backend => "http://test:$TEST_NGINX_SERVER_PORT/",
        hosts => ["one"],
        proxy_rules => [
          { pattern => '/', http_method => 'GET', metric_system_name => 'hits', delta => 1  }
        ]
    }
  }
  ],
  oidc => [
  {service_id => 12},
  {
    service_id => 24,
    issuer => 'https://example.com/auth/realms/apicast_zero',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  },
  {
    service_id => 42,
    issuer => 'https://example.com/auth/realms/apicast_one',
    config => { id_token_signing_alg_values_supported => [ 'RS256' ] },
    keys => { somekid => { pem => $::public_key, alg => 'RS256' } },
  }]
});
--- upstream
  location /test {
    echo "yes";
  }
--- backend
  location = /transactions/oauth_authrep.xml {
    content_by_lua_block {
      local expected = "provider_key=fookey&service_id=42&usage%5Bhits%5D=1&app_id=appid"
      require('luassert').same(ngx.decode_args(expected), ngx.req.get_uri_args(0))
    }
  }
--- request: GET /test
--- error_code: 200
--- more_headers eval
use Crypt::JWT qw(encode_jwt);
my $jwt = encode_jwt(payload => {
  aud => 'something',
  azp => 'appid',
  sub => 'someone',
  iss => 'https://example.com/auth/realms/apicast_one',
  exp => time + 3600 }, key => \$::private_key, alg => 'RS256', extra_headers => { kid => 'somekid' });
"Authorization: Bearer $jwt\r\nHost: one";
--- no_error_log
[error]

=== TEST 4: load a config where only some of the services have an OIDC configuration
This is a regression test. APIcast crashed when loading a config where only
some of the services used OIDC.
The reason is that we created an array of OIDC configs with
size=number_of_services. Let's say we have 100 services and only the 50th has an
OIDC config. In this case, we created this Lua table:
{ [50] = oidc_config_here }.
The problem is that cjson raises an error when trying to convert a sparse array
like that into JSON. Using the default cjson configuration, the minimum number
of elements to reproduce the error is 11. So in this test, we create 11 services
and assign an OIDC config only to the last one. Check
https://www.kyne.com.au/~mark/software/lua-cjson-manual.html#encode_sparse_array
for more details.
Now we assign to _false_ the elements of the array that do not have an OIDC
config, so this test should not crash.
--- env eval
(
  'THREESCALE_DEPLOYMENT_ENV' => 'production',
  'APICAST_CONFIGURATION_LOADER' => 'lazy',
  'APICAST_SERVICES_LIST' => '1,2,3,4,5,6,7,8,9,10,11',
  'THREESCALE_PORTAL_ENDPOINT' => "http://test:$ENV{TEST_NGINX_SERVER_PORT}"
)
--- upstream env
location ~ /admin/api/services/([0-9]|10)/proxy/configs/production/latest.json {
echo '
{
  "proxy_config": {
    "content": {
      "id": 1,
      "backend_version": 1,
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api/",
        "backend": {
          "endpoint": "http://test:$TEST_NGINX_SERVER_PORT"
        },
        "proxy_rules": [
          {
            "pattern": "/",
            "http_method": "GET",
            "metric_system_name": "test",
            "delta": 1
          }
        ]
      }
    }
  }
}
';
}

location = /admin/api/services/11/proxy/configs/production/latest.json {
echo '{ "proxy_config": { "content": { "proxy": { "oidc_issuer_endpoint": "http://test:$TEST_NGINX_SERVER_PORT/issuer/endpoint" } } } }';
}

location = /issuer/endpoint/.well-known/openid-configuration {
  content_by_lua_block {
    local base = "http://" .. ngx.var.host .. ':' .. ngx.var.server_port
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say(require('cjson').encode {
        issuer = 'https://example.com/auth/realms/apicast',
        id_token_signing_alg_values_supported = { 'RS256' },
        jwks_uri = base .. '/jwks',
    })
  }
}

location = /jwks {
  content_by_lua_block {
    ngx.header.content_type = 'application/json;charset=utf-8'
    ngx.say([[
        { "keys": [
            { "kty":"RSA","kid":"somekid",
              "n":"sKXP3pwND3rkQ1gx9nMb4By7bmWnHYo2kAAsFD5xq0IDn26zv64tjmuNBHpI6BmkLPk8mIo0B1E8MkxdKZeozQ","e":"AQAB" }
        ] }
    ]])
  }
}

location /api/ {
  echo 'yay, api backend';
}

--- backend
location /transactions/authrep.xml {
content_by_lua_block { ngx.exit(200) }
}

--- request
GET /?user_key=uk
--- error_code: 200
--- response_body
yay, api backend
