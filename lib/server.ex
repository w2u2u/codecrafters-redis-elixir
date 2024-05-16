defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  @doc """
  Listen for incoming connections
  """
  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(6379, [:binary, active: false, reuseaddr: true])

    accept_connection(socket)
  end

  defp accept_connection(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Task.start(fn -> handle_connection(client) end)

    accept_connection(socket)
  end

  defp handle_connection(client) do
    case read_message(client) do
      "Connection closed" ->
        :ok

      message ->
        message
        |> IO.inspect(label: "Receive")
        |> RedisProtocol.parse_command()
        |> IO.inspect(label: "Command")
        |> handle_command()
        |> IO.inspect(label: "Response")
        |> write_message(client)

        handle_connection(client)
    end
  end

  defp read_message(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, message} ->
        message

      {:error, :closed} ->
        "Connection closed"

      {:error, message} ->
        raise "Failed to read TCP message: #{message}"
        "Failed to read TCP message: #{message}"
    end
  end

  defp handle_command(cmd) do
    case cmd do
      {:ping} -> "PONG" |> RedisProtocol.to_simple()
      {:echo, message} -> message |> RedisProtocol.to_bulk()
      _ -> "+OK\r\n"
    end
  end

  defp write_message(message, client) do
    :gen_tcp.send(client, message)
  end
end

defmodule RedisProtocol do
  def to_simple(string),
    do: "+#{string}\r\n"

  def to_bulk(string),
    do: "$#{String.length(string)}\r\n#{string}\r\n"

  def parse_command(input),
    do:
      input
      |> String.split("\r\n")
      |> to_list([])
      |> Enum.reverse()
      |> to_command()

  defp to_list(["*" <> _length | rest], acc),
    do: to_list(rest, acc)

  defp to_list(["$" <> _length | [value | rest]], acc),
    do: to_list(rest, [value | acc])

  defp to_list(["" | rest], acc),
    do: to_list(rest, acc)

  defp to_list([value | rest], acc),
    do: to_list(rest, [value | acc])

  defp to_list([], acc),
    do: acc

  defp to_command([cmd]),
    do: {cmd |> String.downcase() |> String.to_atom()}

  defp to_command([cmd | args]) do
    cmd = cmd |> String.downcase() |> String.to_atom()
    ([cmd] ++ args) |> List.to_tuple()
  end
end
