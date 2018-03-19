FROM alpine:3.7
MAINTAINER Rohith Jayawardene <gambol99@gmail.com>
LABEL Name=keycloak-proxy \
      Release=https://github.com/kublr/keycloak-proxy \
      Url=https://github.com/kublr/keycloak-proxy \
      Help=https://github.com/kublr/keycloak-proxy/issues

RUN apk add --no-cache ca-certificates

ADD templates/ /opt/templates
ADD bin/keycloak-proxy /opt/keycloak-proxy

WORKDIR "/opt"

ENTRYPOINT [ "/opt/keycloak-proxy" ]
