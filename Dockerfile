FROM elixir:1.9.1-alpine
RUN apk update && apk add git

ENV MIX_ENV prod
WORKDIR /srv
RUN mix local.rebar --force
RUN mix local.hex --force

COPY . .
RUN mix do deps.get, deps.compile, compile

CMD mix run --no-halt
