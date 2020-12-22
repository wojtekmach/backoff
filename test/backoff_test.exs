defmodule BackoffTest do
  use ExUnit.Case, async: true

  test "it works" do
    b = Backoff.new(backoff_min: 1000)
    {time, b} = Backoff.backoff(b)
    IO.inspect(time)
    {time, b} = Backoff.backoff(b)
    IO.inspect(time)
    {time, b} = Backoff.backoff(b)
    IO.inspect(time)
    _ = b
  end
end
