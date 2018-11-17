# PeertubeIndex

**TODO: Add description**

## Decisions
We should not put too much pressure on instances by querying them heavily.

## Tests

To run storage tests you need an ElasticSearch instance running.
Use config/test.exs configure the instance to use for the tests.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `peertube_index` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:peertube_index, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/peertube_index](https://hexdocs.pm/peertube_index).

