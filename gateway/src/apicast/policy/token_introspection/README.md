# OAuth 2.0 Token Introspection

 The OAuth 2.0 Token Introspection policy allows validating the JSON Web Token (JWT) token used for services with the OpenID Connect (OIDC) authentication option using the Token Introspection Endpoint of the token issuer.

APIcast supports the following authentication types in the `auth_type` field to determine the Token Introspection Endpoint and the credentials APIcast uses when calling this endpoint:
* `use_3scale_oidc_issuer_endpoint`: APIcast uses the client credentials, Client ID and Client Secret, as well as the Token Introspection Endpoint from the OIDC Issuer setting configured on the Service Integration page. APIcast discovers the Token Introspection endpoint from the token_introspection_endpoint field. This field is located in the .well-known/openid-configuration endpoint that is returned by the OIDC issuer.
* `client_id+client_secret`: specify a different Token Introspection Endpoint, as well as the Client ID and Client Secret APIcast uses to request token information.
* `client_secret_jwt`: Request token information using `client_secret_jwt` method. Prior to a token information request, APIcast will prepare a new JWT authentication token and sign using HMAC SHA-256 and with Client Secret as the shared key. APIcast will then make a token request including the generated client assertion as the value of the `client_assertion` parameter.
* `private_key_jwt`: using asymmetric key to request token information from OIDC provider. Prior to a token information request, APIcast will prepare a new JWT authentication token and sign with the key provided. APIcast will then make a token request including the generated client assertion as the value of the `client_assertion` parameter.

 The response of the Token Introspection Endpoint contains the active attribute. APIcast checks the value of this attribute. Depending on the value of the attribute, APIcast authorizes or rejects the call:
* `true`: The call is authorized
* `false`: The call is rejected with the Authentication Failed error

The policy allows enabling caching of the tokens to avoid calling the Token Introspection Endpoint on every call for the same JWT token. To enable token caching for the Token Introspection Policy, set the max_cached_tokens field to a value from 0, which disables the feature, and 10000. Additionally, you can set a Time to Live (TTL) value from 1 to 3600 seconds for tokens in the max_ttl_tokens field. 

## Examples:

- With `use_3scale_oidc_issuer_endpoint`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "use_3scale_oidc_issuer_endpoint",
  }
}
```

- With `client_id+client_secret`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "client_id+client_secret",
    "client_id": "myclient",
    "client_secret": "mysecret",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection"
  }
}
```

- With `client_secret_jwt`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "client_secret_jwt",
    "client_id": "myclient",
    "client_secret": "mysecret",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection",
    "client_jwt_assertion_audience": "http://red_hat_single_sign-on/auth/realms/basic"
  }
}
```

- With `private_key_jwt`

```
{
  "name": "apicast.policy.token_introspection",
  "configuration": {
    "auth_type": "private_key_jwt",
    "client_id": "myclient",
    "client_secret": "mysecret",
    "introspection_url": "http://red_hat_single_sign-on/token/introspection"
    "certificate_type": "embedded",
    "certificate": "data:application/x-x509-ca-cert;name=rsa.pem;base64,XXXXXXXXXxx",
  }
}
```
