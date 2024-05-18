defmodule Server.Tcp do
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
      {:ping} ->
        "PONG" |> RedisProtocol.simple()

      {:get, key} ->
        case Server.Database.get(key) do
          {:ok, value} -> value |> RedisProtocol.bulk()
          {:notfound} -> RedisProtocol.bulk(:null)
        end

      {:set, key, value, _px, ms} ->
        {ms, _} = Integer.parse(ms)
        Server.Database.set(key, value, ms)
        "OK" |> RedisProtocol.simple()

      {:set, key, value} ->
        Server.Database.set(key, value)
        "OK" |> RedisProtocol.simple()

      {:echo, message} ->
        message |> RedisProtocol.bulk()

      _ ->
        "OK" |> RedisProtocol.simple()
    end
  end

  defp write_message(message, client) do
    :gen_tcp.send(client, message)
  end
end
