FROM alpine:3.9
RUN apk update && apk add bash elixir postgresql-client

RUN mkdir /opt/etl
WORKDIR /opt/etl
COPY . .

CMD /bin/bash etl_loop.sh
