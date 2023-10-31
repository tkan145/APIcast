# APIcast GRPC endpoint

## Create the SSL Certificates

```sh
make gateway-certs
```

```sh
make upstream-certs
```

## Run the gateway

Running local `apicast-test` docker image

```sh
make gateway
```

Running custom apicast image

```sh
make gateway IMAGE_NAME=quay.io/3scale/apicast:latest
```

Traffic between the gateway and upstream can be inspected looking at logs from `one.upstream` service

```
docker compose -p grpc logs -f one.upstream
```

## Testing


Get `grpcurl`

```sh
make grpcurl
```

Run request

```sh
bin/grpcurl -vv -insecure -H "app_id: abc123" -H "app_key: abc123" -authority gateway.example.com 127.0.0.1:8443 main.HelloWorld/Greeting
```

## Clean env

```sh
make clean
```
