FROM dockerhub.ir/golang as builder

WORKDIR /go/src/app
COPY . .

RUN go build .

FROM dockerhub.ir/ubuntu:18.04

COPY --from=builder /go/src/app/smokescreen /usr/local/bin/smokescreen
COPY acl.yaml /etc/smokescreen/acl.yaml