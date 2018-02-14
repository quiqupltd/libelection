# Libelection

[![Build Status](https://travis-ci.org/QuiqUpLTD/libelection.svg?branch=master)](https://travis-ci.org/QuiqUpLTD/libelection)
[![Package Version](https://img.shields.io/hexpm/v/libelection.svg)](https://hex.pm/packages/libelection)

Library to perform leader election in a cluster of containerized Elixir nodes.

## Installation

```elixir
def deps do
  [{:libelection, "~> 0.2.0"}]
end
```

## Election Strategies

### Rancher

```elixir
config :libelection,
  strategy: Election.Strategy.Rancher,
  rancher_node_basename: "some-app"
```

### Kubernetes

```elixir
config :libelection,
  strategy: Election.Strategy.Kubernetes,
  kubernetes_selector: "app=some-app",
  kubernetes_node_basename: "some-app"
```

## Documentation

* [exdoc](https://hexdocs.pm/libelection/)
* wiki (coming soon)

## License

GPLv3
