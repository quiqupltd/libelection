<p align="center"><img src="design/logo.png" alt="libelection" height="300px"></p>


# Libelection

[![Build Status](https://travis-ci.org/quiqupltd/libelection.svg?branch=master)](https://travis-ci.org/quiqupltd/libelection)
[![Package Version](https://img.shields.io/hexpm/v/libelection.svg)](https://hex.pm/packages/libelection)
[![Coverage](https://coveralls.io/repos/github/quiqupltd/libelection/badge.svg?branch=master)](https://coveralls.io/repos/github/quiqupltd/libelection)
[![Inline docs](https://inch-ci.org/github/quiqupltd/libelection.svg?branch=master)](https://inch-ci.org/github/quiqupltd/libelection)

Library to perform leader election in a cluster of containerized Elixir nodes.

## Installation

```elixir
def deps do
  [{:libelection, "~> 1.1.0"}]
end
```

## Usage

```elixir

if Election.leader? do
  # Code path executed only by the leader node
else
  # Code path executed by followers
end
```

## How it works

Polls the API of the configured container orchestration platform to determine the oldest node of the cluster.

To configure the polling interval use:

```elixir
config :libelection, :polling_interval, 2_000 # 2 seconds
```

To configure the function which lists the node of the cluster use:

```elixir
config :libelection, :list_nodes, {module, function, args}
# it can also be a function reference
config :libelection, :list_nodes, &SomeModule.some_function/1
```

Configure the logger
```elixir
config :libelection, :logger, %{level: :debug} # Default
```

*Note:* The configuration also supports [confex](https://hex.pm/packages/confex) style configurations.

## Election Strategies

### Rancher

The [`create_index`](http://rancher.com/docs/rancher/v1.2/en/rancher-services/metadata-service/#container) identifier is used to pick the leader.

```elixir
config :libelection,
  strategy: Election.Strategy.Rancher,
  rancher_node_basename: "some-app"
```

### Kubernetes

The [`resourceVersion`](https://kubernetes.io/docs/reference/generated/federation/v1/definitions/) identifier
is used to pick the leader.

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

[GPLv3](https://github.com/quiqupltd/libelection/blob/master/LICENSE.md)
