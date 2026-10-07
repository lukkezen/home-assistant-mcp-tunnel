FROM ghcr.io/openai/tunnel-client:v0.0.16 AS tunnel

FROM ghcr.io/home-assistant/base:3.22

RUN apk add --no-cache bash jq

COPY --from=tunnel /usr/bin/tunnel-client /usr/local/bin/tunnel-client
COPY run.sh /run.sh

RUN chmod 0755 /run.sh /usr/local/bin/tunnel-client

CMD ["/run.sh"]
