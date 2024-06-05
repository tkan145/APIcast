# FAPI Policy

## Description

The FAPI policy supports various features of the Financial-grade API (FAPI) standard.

## Example configuration

```
"policy_chain": [
    { "name": "apicast.policy.fapi", "configuration": {} },
    {
      "name": "apicast.policy.apicast"
    }
]
```

### Validate x-fapi-customer-ip-address header

```
"policy_chain": [
    {
      "name": "apicast.policy.fapi",
      "configuration": {
        "validate_x_fapi_customer_ip_address": true
      }
    },
    {
      "name": "apicast.policy.apicast"
    }
]
```
