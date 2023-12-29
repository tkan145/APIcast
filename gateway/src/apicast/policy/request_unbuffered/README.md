# APICast Request Unbuffered

This policy allows to disable request buffering

## Example configuration

```
{
    "name": "request_unbuffered",
    "version": "builtin",
    "configuration": {}
}
```

## Caveats

- Because APIcast allows defining mapping rules based on request content, POST requests with
  `Content-type: application/x-www-form-urlencoded` will always be buffered regardless of the
  `request_unbuffered` policy is enabled or not.
