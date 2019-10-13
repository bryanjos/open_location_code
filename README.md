# OpenLocationCode

An implementation of Google's [Open Location Code](https://github.com/google/open-location-code) in Elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `open_location_code` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:open_location_code, "~> 1.0.0"}
  ]
end
```

### Usage

```elixir
iex(1)> OpenLocationCode.encode(47.0000625,8.0000625)
{:ok, "8FVC2222+22"}

iex(2)> OpenLocationCode.decode("8FVC2222+22")
{:ok,
 %OpenLocationCode.CodeArea{
   code_length: 10,
   latitude_center: 47.0000625,
   latitude_height: 1.25e-4,
   longitude_center: 8.0000625,
   longitude_width: 1.25e-4,
   south_latitude: 47.0,
   west_longitude: 8.0
 }}

iex(3)> OpenLocationCode.valid?("8FVC2222+22")
true
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/open_location_code](https://hexdocs.pm/open_location_code).
