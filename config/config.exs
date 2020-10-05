import Config

maybe_get_int = fn var ->
  case System.get_env(var, "") do
    "" -> nil
    value -> String.to_integer(value)
  end
end

unless System.get_env("BAKEWARE_ARGC") do
  System.put_env("BAKEWARE_ARGC", "0")
end
