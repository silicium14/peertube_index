FROM alpine:3.9
RUN apk update && apk add elixir postgresql-client

RUN mkdir /opt/etl
WORKDIR /opt/etl
COPY . .

CMD /bin/sh etl_loop.sh
