# TLS Validation policy

This policy can validate TLS Client Certificate against a whitelist.

Whitelist expects PEM formatted CA or Client certificates.
It is not necessary to have the full certificate chain, just partial matches are allowed.
For example you can add to the whitelist just leaf client certificates without the whole bundle with a CA certificate.

## Configuration

For this policy to work, APIcast need to be setup to listen for TLS connection.

By default, client certificates are requested during the TLS handshake, however, APIcast will not verify the certificate or terminate the request unless a TLS Validation Policy is in the chain. In most cases, the client not presenting a client certificate will not affect a service that does not have TLS Validation policy configured. The only exception is when the service is used by a browser or front-end application, which will cause the browser to always prompt the end user to select a client certificate to send if they have ANY client certificates configured when browsing the service.

To work around this, the environment variable `APICAST_HTTPS_VERIFY_CLIENT` can be set to `off` to instruct APIcast to request a client certificate ONLY when the policy is in the chain.

NOTE: This policy is not compatible with `APICAST_PATH_ROUTING` or `APICAST_PATH_ROUTING_ONLY` when `APICAST_HTTPS_VERIFY_CLIENT` is set to `off`.

## Example

```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ]
  }
}
```
