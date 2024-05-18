defmodule Server.Database do
  use Agent

  def start_link(initial_state \\ %{}) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  def get(key) do
    case Agent.get(__MODULE__, &Map.get(&1, key)) do
      {value, :infinite} ->
        {:ok, value}

      {value, expires_at} ->
        if expires_at > :os.system_time(:millisecond) do
          {:ok, value}
        else
          {:notfound}
        end

      _ ->
        {:notfound}
    end
  end

  def set(key, value, expires_at \\ :infinite) do
    expires_at =
      case expires_at do
        :infinite -> :infinite
        ms -> :os.system_time(:millisecond) + ms
      end

    Agent.update(
      __MODULE__,
      &Map.put(&1, key, {value, expires_at})
    )
  end
end
