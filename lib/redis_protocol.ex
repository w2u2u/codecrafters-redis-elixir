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
