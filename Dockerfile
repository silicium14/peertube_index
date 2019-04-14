FROM elixir:1.8-alpine

ENV MIX_ENV prod
WORKDIR /srv
RUN mix local.rebar --force
RUN mix local.hex --force

COPY . .
RUN mix do deps.get, deps.compile, compile

CMD mix run --no-halt
