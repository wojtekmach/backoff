# Based on:
# https://github.com/elixir-ecto/db_connection/blob/v2.3.0/lib/db_connection/backoff.ex
#
# Copyright 2015 James Fish
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
defmodule Backoff do
  @moduledoc false

  @default_type :rand_exp
  @min 1_000
  @max 30_000

  defstruct [:type, :min, :max, :state]

  # Options:
  #
  #  * `:backoff_type` - `:exp`, `:rand`, `:rand_exp` (default)
  #  * `:backoff_min`
  #  * `:backoff_max`
  def new(opts) do
    case Keyword.get(opts, :backoff_type, @default_type) do
      :stop ->
        nil

      type ->
        {min, max} = min_max(opts)
        new(type, min, max)
    end
  end

  def backoff(%Backoff{type: :rand, min: min, max: max, state: state} = s) do
    {backoff, state} = rand(state, min, max)
    {backoff, %Backoff{s | state: state}}
  end

  def backoff(%Backoff{type: :exp, min: min, state: nil} = s) do
    {min, %Backoff{s | state: min}}
  end

  def backoff(%Backoff{type: :exp, max: max, state: prev} = s) do
    require Bitwise
    next = min(Bitwise.<<<(prev, 1), max)
    {next, %Backoff{s | state: next}}
  end

  def backoff(%Backoff{type: :rand_exp, max: max, state: state} = s) do
    {prev, lower, rand_state} = state
    next_min = min(prev, lower)
    next_max = min(prev * 3, max)
    {next, rand_state} = rand(rand_state, next_min, next_max)
    {next, %Backoff{s | state: {next, lower, rand_state}}}
  end

  def reset(%Backoff{type: :rand} = s), do: s
  def reset(%Backoff{type: :exp} = s), do: %Backoff{s | state: nil}

  def reset(%Backoff{type: :rand_exp, min: min, state: state} = s) do
    {_, lower, rand_state} = state
    %Backoff{s | state: {min, lower, rand_state}}
  end

  ## Internal

  defp min_max(opts) do
    case {opts[:backoff_min], opts[:backoff_max]} do
      {nil, nil} -> {@min, @max}
      {nil, max} -> {min(@min, max), max}
      {min, nil} -> {min, max(min, @max)}
      {min, max} -> {min, max}
    end
  end

  defp new(_, min, _) when not (is_integer(min) and min >= 0) do
    raise ArgumentError, "minimum #{inspect(min)} not 0 or a positive integer"
  end

  defp new(_, _, max) when not (is_integer(max) and max >= 0) do
    raise ArgumentError, "maximum #{inspect(max)} not 0 or a positive integer"
  end

  defp new(_, min, max) when min > max do
    raise ArgumentError, "minimum #{min} is greater than maximum #{max}"
  end

  defp new(:rand, min, max) do
    %Backoff{type: :rand, min: min, max: max, state: seed()}
  end

  defp new(:exp, min, max) do
    %Backoff{type: :exp, min: min, max: max, state: nil}
  end

  defp new(:rand_exp, min, max) do
    lower = max(min, div(max, 3))
    %Backoff{type: :rand_exp, min: min, max: max, state: {min, lower, seed()}}
  end

  defp new(type, _, _) do
    raise ArgumentError, "unknown type #{inspect(type)}"
  end

  defp seed() do
    :rand.seed_s(:exsplus)
  end

  defp rand(state, min, max) do
    {int, state} = :rand.uniform_s(max - min + 1, state)
    {int + min - 1, state}
  end
end
