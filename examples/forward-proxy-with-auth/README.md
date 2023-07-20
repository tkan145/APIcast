# PROXY with Basic Auth

APIcast --> tiny proxy setup with Basic Auth --> upstream

```
curl -v -H "Host: one" http://${APICAST_IP}:8080/get?user_key=foo
```
