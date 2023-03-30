# upstream using TLSv1.3

APIcast --> upstream (TLSv1.3)

APicast configured to access TLSv1.3 powered upstream

```
curl -v -H "Host: one" http://${APICAST_IP}:8080/?user_key=foo
```

NOTE: using `one.upstream` as upstream hostname becase when APIcast resolves `upstream` it returns `0.0.0.1`
