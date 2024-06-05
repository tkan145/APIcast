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
