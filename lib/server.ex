defmodule Server do
  @moduledoc """
  Your implementation of a Redis server
  """

  use Application

  def start(_type, _args) do
    Supervisor.start_link(
      [
        {Task, fn -> Server.Tcp.listen() end},
        {Server.Database, %{}}
      ],
      strategy: :one_for_one
    )
  end
end
