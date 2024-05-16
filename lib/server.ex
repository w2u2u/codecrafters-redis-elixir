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

    handle_connection(client)

    accept_connection(socket)
  end

  defp handle_connection(client) do
    client
    |> read_message()
    |> IO.inspect(label: "Receive")
    |> RedisParser.parse()
    |> IO.inspect(label: "Command")
    |> handle_command()
    |> IO.inspect(label: "Response")
    |> write_message(client)
  end

  defp read_message(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, message} ->
        message

      {:error, message} ->
        raise "Failed to read TCP message: #{message}"
        "Failed to read TCP message: #{message}"
    end
  end

  defp handle_command(cmd) do
    case cmd do
      {:ping} -> "+PONG\r\n"
      _ -> "+OK\r\n"
    end
  end

  defp write_message(message, client) do
    :gen_tcp.send(client, message)
  end
end

defmodule RedisParser do
  def parse(input),
    do:
      input
      |> String.split("\r\n")
      |> parse_lines([])
      |> Enum.reverse()
      |> parse_command()

  defp parse_lines(["*" <> _length | rest], acc), do: parse_lines(rest, acc)

  defp parse_lines(["$" <> _length | [value | rest]], acc), do: parse_lines(rest, [value | acc])

  defp parse_lines(["" | rest], acc), do: parse_lines(rest, acc)

  defp parse_lines([value | rest], acc), do: parse_lines(rest, [value | acc])

  defp parse_lines([], acc), do: acc

  defp parse_command([cmd]), do: {cmd |> String.downcase() |> String.to_atom()}
  defp parse_command([cmd | args]), do: {cmd |> String.downcase() |> String.to_atom(), args}
end
