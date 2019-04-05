defmodule Election.ConfigTest do
  use ExUnit.Case, async: false

  alias Election.Config

  def setup_all do
    default = Application.get_all_env(:libelection)

    on_exit(fn ->
      Application.put_env(:libelection, default)
      System.delete_env("K8S_SELECTOR")
    end)
  end

  describe "fetch_config/0" do
    test "it returns the requested value when it is set" do
      value = "k8s-app-selector"

      Application.put_env(
        :libelection,
        :kubernetes_selector,
        value
      )

      k8s_selector = Config.fetch_config() |> Access.get(:kubernetes_selector)

      assert k8s_selector == value
    end

    test "it accepts Confex style configuration tuples" do
      value = "app-selector"
      default_value = "default-app-selector"

      System.put_env([
        {"K8S_SELECTOR", value}
      ])

      Application.put_env(
        :libelection,
        :kubernetes_selector,
        {:system, "K8S_SELECTOR", default_value}
      )

      k8s_selector = Config.fetch_config() |> Access.get(:kubernetes_selector)
      assert k8s_selector == value

      System.delete_env("K8S_SELECTOR")
    end

    test "it sets a default value when the variable is not present" do
      default_value = "default-app-selector"

      Application.put_env(
        :libelection,
        :kubernetes_selector,
        {:system, "K8S_SELECTOR", default_value}
      )

      k8s_selector = Config.fetch_config() |> Access.get(:kubernetes_selector)

      assert k8s_selector == default_value
    end

    test "it returns nil when default is not present" do
      Application.put_env(
        :libelection,
        :kubernetes_selector,
        {:system, "K8S_SELECTOR"}
      )

      k8s_selector = Config.fetch_config() |> Access.get(:kubernetes_selector)

      refute k8s_selector
    end

    test "it returns a function when an anonymous function is passed" do
      remote_node = :somenode@somehost

      Application.put_env(:libelection, :list_nodes, fn -> [node(), remote_node] end)

      result = Config.fetch_config() |> Access.get(:list_nodes)

      assert is_function(result)
    end
  end
end
