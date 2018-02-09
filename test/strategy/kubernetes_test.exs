defmodule Election.Strategy.KubernetesTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Election.Strategy.Kubernetes, as: Subject

  @config %{
    kubernetes_node_basename: "example",
    kubernetes_selector: "app=example"
  }

  describe "leader/2 without connected nodes" do
    setup do
      {:ok, %{subject: &(Subject.leader([], &1))}}
    end

    test "when fetching nodes fails with a 500 error, returns nil", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 500, "Some error message")
      end)

      log = capture_log fn ->
        assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) == nil
      end

      assert log =~ "cannot query kubernetes (500 Internal Server Error)"
    end

    test "when fetching nodes fails due to authorization error, returns nil", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 403, "{\"message\": \"Authorization failed\"}")
      end)

      log = capture_log fn ->
        assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) == nil
      end

      assert log =~ "cannot query kubernetes (unauthorized)"
    end

    test "when other nodes are discovered but not included in the connected nodes, returns nil", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(fixture(:kubernetes_api_response)))
      end)

      assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) == nil
    end
  end

  describe "leader/2 with connected nodes" do
    setup do
      nodes = [:'example@192.168.1.1', :'example@192.168.1.2', :'example@192.168.1.3']
      {:ok, %{subject: &(Subject.leader(nodes, &1))}}
    end

    test "when fetching nodes fails with a 500 error, returns nil", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 500, "Some error message")
      end)

      log = capture_log fn ->
        assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) == nil
      end

      assert log =~ "cannot query kubernetes (500 Internal Server Error)"
    end

    test "when fetching nodes fails due to authorization error, returns nil", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 403, "{\"message\": \"Authorization failed\"}")
      end)

      log = capture_log fn ->
        assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) == nil
      end

      assert log =~ "cannot query kubernetes (unauthorized)"
    end

    test "when other nodes are discovered, returns the node with the lowest resourceVersion", %{subject: subject} do
      bypass = Bypass.open()
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 200, Poison.encode!(fixture(:kubernetes_api_response)))
      end)

      expectation = %{metadata: %{create_index: 80}, node: :"example@192.168.1.2"}

      assert subject.(put_in(@config[:kubernetes_api_base_url], kubernetes_base_url(bypass))) ==  expectation
    end
  end

  defp kubernetes_base_url(%{port: port}), do: "http://localhost:#{port}" |> String.to_charlist

  defp fixture(:kubernetes_api_response) do
    %{
      "apiVersion" => "v1",
      "items" => [%{"metadata" => %{"creationTimestamp" => "2018-01-11T13:03:10Z",
        "labels" => %{"app" => "example", "strategy" => "full"},
        "name" => "example", "namespace" => "default",
        "resourceVersion" => "5127743",
        "selfLink" => "/api/v1/namespaces/default/endpoints/example",
        "uid" => "c64dc5ff-f6cf-11e7-a513-42010a9c01f0"},
        "subsets" => [%{
          "addresses" => [%{"ip" => "192.168.1.1",
          "nodeName" => "some-node-name",
          "targetRef" => %{"kind" => "Pod",
            "name" => "example-4204218243-7g0pr", "namespace" => "default",
            "resourceVersion" => "100",
            "uid" => "1a42feb7-0ffd-11e8-bc95-42010a9c0154"}},
               %{"ip" => "192.168.1.2",
                 "nodeName" => "some-node-name",
                 "targetRef" => %{"kind" => "Pod",
                   "name" => "example-4204218243-98sh4", "namespace" => "default",
                   "resourceVersion" => "80",
                   "uid" => "3e32b139-0ffd-11e8-bc95-42010a9c0154"}},
               %{"ip" => "192.168.1.3",
                 "nodeName" => "some0-node-name",
                 "targetRef" => %{"kind" => "Pod",
                   "name" => "example-4204218243-n1t2r", "namespace" => "default",
                   "resourceVersion" => "120",
                   "uid" => "fc60f592-0ffc-11e8-bc95-42010a9c0154"}}],
          "ports" => [%{"port" => 4000, "protocol" => "TCP"}]}]}],
      "kind" => "EndpointsList",
      "metadata" => %{"resourceVersion" => "5143116", "selfLink" => "/api/v1/namespaces/default/endpoints"}
    }
  end
end
