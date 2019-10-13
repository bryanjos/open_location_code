defmodule OpenLocationCode do
  @moduledoc """
  Documentation for OpenLocationCode.
  """
  require Integer

  # The character set used to encode coordinates.
  @code_alphabet "23456789CFGHJMPQRVWX"

  # The character used to pad a code
  @padding "0"

  # A separator used to separate the code into two parts.
  @separator "+"

  # The max number of characters can be placed before the separator.
  @separator_position 8

  # Maximum number of digits to process in a plus code.
  @max_code_length 15

  # Maximum code length using lat/lng pair encoding. The area of such a
  # code is approximately 13x13 meters (at the equator), and should be suitable
  # for identifying buildings. This excludes prefix and separator characters.
  @pair_code_length 10

  # Inverse of the precision of the pair code section.
  @pair_code_precision 8000

  # Precision of the latitude grid.
  @lat_grid_precision round(:math.pow(5, @max_code_length - @pair_code_length))

  # Precision of the longitude grid.
  @lng_grid_precision round(:math.pow(4, @max_code_length - @pair_code_length))

  @decode Enum.reduce(String.graphemes(@code_alphabet) ++ [@padding, @separator], %{}, fn c,
                                                                                          ary ->
            case :binary.match(@code_alphabet, c) do
              :nomatch ->
                ary
                |> Map.put(:binary.first(c), -1)
                |> Map.put(:binary.first(String.downcase(c)), -1)

              {index, _} ->
                ary
                |> Map.put(:binary.first(c), index)
                |> Map.put(
                  :binary.first(String.downcase(c)),
                  :binary.match(@code_alphabet, c) |> elem(0)
                )
            end
          end)

  @doc """
  Generates a Open Location Code from the given coordinates.
  latitude and longitude

  ## Examples

      iex> OpenLocationCode.encode(29.952062, -90.077188)
      {:ok, "76XFXW2F+R4"}

  """
  @spec encode(number(), number(), integer()) :: {:ok, binary()} | {:error, binary()}
  def encode(latitude, longitude, code_length \\ @pair_code_length) do
    try do
      code = encode!(latitude, longitude, code_length)
      {:ok, code}
    rescue
      x ->
        {:error, x.message}
    end
  end

  @doc """
  Same as encode/1 except will throw an exception if invalid

  ## Examples

      iex> OpenLocationCode.encode!(29.952062, -90.077188)
      "76XFXW2F+R4"

  """
  @spec encode!(number(), number(), integer()) :: binary()
  def encode!(latitude, longitude, code_length \\ @pair_code_length) do
    if invalid_length?(code_length),
      do: raise(ArgumentError, message: "Invalid Open Location Code length")

    code_length =
      if code_length > @max_code_length do
        @max_code_length
      else
        code_length
      end

    latitude = clip_latitude(latitude)
    longitude = normalize_longitude(longitude)

    latitude =
      if latitude == 90 do
        latitude - precision_by_length(code_length)
      else
        latitude
      end

    lat_val = 90 * @pair_code_precision * @lat_grid_precision
    lat_val = lat_val + latitude * @pair_code_precision * @lat_grid_precision

    lng_val = 180 * @pair_code_precision * @lng_grid_precision
    lng_val = lng_val + longitude * @pair_code_precision * @lng_grid_precision

    lat_val = Float.floor(lat_val) |> round()
    lng_val = Float.floor(lng_val) |> round()

    {code, lat_val, lng_val} =
      if code_length > @pair_code_length do
        range = 0..(@max_code_length - @pair_code_length - 1)
        init_value = {"", lat_val, lng_val}

        Enum.reduce(range, init_value, fn _, {code, lat_val, lng_val} ->
          index = Integer.mod(lat_val, 5) * 4 + Integer.mod(lng_val, 4)
          code = String.at(@code_alphabet, index) <> code
          lat_val = Integer.floor_div(lat_val, 5)
          lng_val = Integer.floor_div(lng_val, 4)

          {code, lat_val, lng_val}
        end)
      else
        lat_val = Integer.floor_div(lat_val, @lat_grid_precision)
        lng_val = Integer.floor_div(lng_val, @lng_grid_precision)
        {"", lat_val, lng_val}
      end

    range = 0..(round(@pair_code_length / 2) - 1)
    init_value = {code, lat_val, lng_val}

    {code, _lat_val, _lng_val} =
      Enum.reduce(
        range,
        init_value,
        fn i, {code, lat_val, lng_val} ->
          code = String.at(@code_alphabet, Integer.mod(lng_val, 20)) <> code
          code = String.at(@code_alphabet, Integer.mod(lat_val, 20)) <> code
          lat_val = Integer.floor_div(lat_val, 20)
          lng_val = Integer.floor_div(lng_val, 20)
          code = if i == 0, do: @separator <> code, else: code
          {code, lat_val, lng_val}
        end
      )

    format_code(code, code_length)
  end

  @doc """
  Generates an OpenLocationCode.CodeArea struct from a given Open Location Code

  """
  @spec decode(binary()) :: {:ok, OpenLocationCode.CodeArea.t()} | {:error, binary()}
  def decode(code) do
    try do
      point = decode!(code)
      {:ok, point}
    rescue
      x ->
        {:error, x.message}
    end
  end

  @doc """
  Same as decode/1 except will throw an exception if invalid

  """
  @spec decode!(binary()) :: OpenLocationCode.CodeArea.t()
  def decode!(code) do
    unless full?(code) do
      raise ArgumentError,
        message: "Open Location Code is not a valid full code: #{code}"
    end

    code =
      code
      |> String.replace(@separator, "")
      |> String.replace(~r/#{@padding}+/, "")
      |> String.upcase()

    code_length = min(String.length(code), @max_code_length)

    south_latitude = -90.0
    west_longitude = -180.0

    lat_resolution = 400
    lng_resolution = 400

    digit = 0

    {south_latitude, west_longitude, lat_resolution, lng_resolution, digit} =
      do_decode(
        code,
        code_length,
        digit,
        lat_resolution,
        lng_resolution,
        south_latitude,
        west_longitude
      )

    latitude_center = south_latitude + lat_resolution / 2.0
    longitude_center = west_longitude + lng_resolution / 2.0

    %OpenLocationCode.CodeArea{
      south_latitude: south_latitude,
      west_longitude: west_longitude,
      latitude_height: lat_resolution,
      longitude_width: lng_resolution,
      code_length: digit,
      latitude_center: latitude_center,
      longitude_center: longitude_center
    }
  end

  defp do_decode(
         _code,
         code_length,
         digit,
         lat_resolution,
         lng_resolution,
         south_latitude,
         west_longitude
       )
       when digit >= code_length do
    {south_latitude, west_longitude, lat_resolution, lng_resolution, digit}
  end

  defp do_decode(
         code,
         code_length,
         digit,
         lat_resolution,
         lng_resolution,
         south_latitude,
         west_longitude
       )
       when digit < @pair_code_length do
    lat_resolution = lat_resolution / 20
    lng_resolution = lng_resolution / 20

    south_latitude =
      south_latitude + lat_resolution * Map.get(@decode, :binary.first(String.at(code, digit)))

    west_longitude =
      west_longitude +
        lng_resolution * Map.get(@decode, :binary.first(String.at(code, digit + 1)))

    do_decode(
      code,
      code_length,
      digit + 2,
      lat_resolution,
      lng_resolution,
      south_latitude,
      west_longitude
    )
  end

  defp do_decode(
         code,
         code_length,
         digit,
         lat_resolution,
         lng_resolution,
         south_latitude,
         west_longitude
       ) do
    lat_resolution = lat_resolution / 5
    lng_resolution = lng_resolution / 4

    row = Map.get(@decode, :binary.first(String.at(code, digit))) |> div(4)
    column = Map.get(@decode, :binary.first(String.at(code, digit))) |> Integer.mod(4)

    south_latitude = south_latitude + lat_resolution * row
    west_longitude = west_longitude + lng_resolution * column

    do_decode(
      code,
      code_length,
      digit + 1,
      lat_resolution,
      lng_resolution,
      south_latitude,
      west_longitude
    )
  end

  @doc """
  Determines if a string is a valid sequence of Open Location Code characters.
  """
  def valid?(code) do
    valid_length?(code) && valid_separator?(code) && valid_padding?(code) &&
      valid_character?(code)
  end

  @doc """
  Determines if a string is a valid short Open Location Code.
  """
  @spec short?(binary()) :: boolean()
  def short?(code) do
    valid?(code) && :binary.match(code, @separator) |> elem(0) < @separator_position
  end

  @doc """
  Determines if a string is a valid full Open Location Code
  """
  @spec full?(binary()) :: boolean()
  def full?(code) do
    valid?(code) && !short?(code)
  end

  @doc """
  Recovers a full Open Location Code from a short code and a
  reference location.
  """
  def recover_nearest(short_code, reference_latitude, reference_longitude) do
    cond do
      full?(short_code) ->
        String.upcase(short_code)

      !short?(short_code) ->
        raise ArgumentError,
          message: "Open Location Code is not valid: #{short_code}"

      true ->
        reference_latitude = clip_latitude(reference_latitude)
        reference_longitude = normalize_longitude(reference_longitude)

        prefix_len = @separator_position - (:binary.match(short_code, @separator) |> elem(0))

        code =
          prefix_by_reference(reference_latitude, reference_longitude, prefix_len) <> short_code

        code_area = decode!(code)

        resolution = precision_by_length(prefix_len)

        half_resolution = resolution / 2

        latitude = code_area.latitude_center

        latitude =
          cond do
            reference_latitude + half_resolution < latitude && latitude - resolution >= -90 ->
              latitude - resolution

            reference_latitude - half_resolution > latitude && latitude + resolution <= 90 ->
              latitude + resolution

            true ->
              latitude
          end

        longitude = code_area.longitude_center

        longitude =
          cond do
            reference_longitude + half_resolution < longitude ->
              longitude - resolution

            reference_longitude - half_resolution > longitude ->
              longitude + resolution

            true ->
              longitude
          end

        encode!(latitude, longitude, String.length(code) - String.length(@separator))
    end
  end

  @doc """
  Removes four, six or eight digits from the front of an Open Location Code
  given a reference location.
  """
  @spec shorten(binary(), number(), number()) :: binary()
  def shorten(code, latitude, longitude) do
    unless full?(code) do
      raise ArgumentError,
        message: "Open Location Code is a valid full code: #{code}"
    end

    unless :binary.match(code, @padding) == :nomatch do
      raise ArgumentError,
        message: "Cannot shorten padded codes: #{code}"
    end

    code_area = decode!(code)
    lat_diff = abs(latitude - code_area.latitude_center)
    lng_diff = abs(longitude - code_area.longitude_center)
    max_diff = max(lat_diff, lng_diff)

    code =
      Enum.reduce_while([8, 6, 4], code, fn removal_len, code ->
        area_edge = precision_by_length(removal_len) * 0.3

        if max_diff < area_edge do
          {:halt, String.slice(code, removal_len..-1)}
        else
          {:cont, code}
        end
      end)

    String.upcase(code)
  end

  defp invalid_length?(code_length) when code_length < 2 do
    true
  end

  defp invalid_length?(code_length)
       when code_length < @pair_code_length and Integer.is_odd(code_length) do
    true
  end

  defp invalid_length?(_) do
    false
  end

  defp clip_latitude(latitude) do
    max = max(-90.0, latitude)
    min(90.0, max)
  end

  defp normalize_longitude(longitude) when longitude <= 180 and longitude >= -180 do
    longitude
  end

  defp normalize_longitude(longitude) when longitude > 180 do
    normalize_longitude(longitude - 360)
  end

  defp normalize_longitude(longitude) when longitude < -180 do
    normalize_longitude(longitude + 360)
  end

  defp precision_by_length(code_length) when code_length <= @pair_code_length do
    value = Integer.floor_div(code_length, -2)
    :math.pow(20, value + 2)
  end

  defp precision_by_length(code_length) do
    1.0 / (:math.pow(20, 3) * :math.pow(5, code_length - @pair_code_length))
  end

  defp format_code(code, code_length) when code_length >= @separator_position do
    String.slice(code, 0, code_length + 1)
  end

  defp format_code(code, code_length) when @separator_position - code_length > 0 do
    String.slice(code, 0, code_length) <>
      String.duplicate(@padding, @separator_position - code_length) <> @separator
  end

  defp valid_length?(nil), do: false

  defp valid_length?(code) when byte_size(code) < 2 + byte_size(@separator), do: false

  defp valid_length?(code) do
    code
    |> String.split(@separator)
    |> List.last()
    |> String.length() != 1
  end

  defp valid_separator?(code) do
    separator_idx = :binary.match(code, @separator) |> elem(0)

    length(String.split(code, @separator)) == 2 && separator_idx <= @separator_position &&
      Integer.is_even(separator_idx)
  end

  defp valid_padding?(code) do
    paddings = Regex.scan(~r/#{@padding}+/, code)

    if String.contains?(code, @padding) do
      cond do
        :binary.match(code, @separator) |> elem(0) < @separator_position ->
          false

        String.starts_with?(code, @padding) ->
          false

        String.slice(code, -2..-1) != @padding <> @separator ->
          false

        length(paddings) > 1 ->
          false

        Enum.at(paddings, 0) |> hd |> String.length() |> Integer.is_odd() ->
          false

        Enum.at(paddings, 0) |> length() > @separator_position - 2 ->
          false

        true ->
          true
      end
    else
      true
    end
  end

  defp valid_character?(code) do
    code =
      code
      |> String.replace(@separator, "")
      |> String.replace(~r/#{@padding}+/, "")
      |> String.upcase()

    Enum.all?(String.graphemes(code), fn ch -> String.contains?(@code_alphabet, ch) end)
  end

  defp prefix_by_reference(latitude, longitude, prefix_len) do
    precision = precision_by_length(prefix_len)
    rounded_latitude = Float.floor(latitude / precision) * precision
    rounded_longitude = Float.floor(longitude / precision) * precision
    code = encode!(rounded_latitude, rounded_longitude)
    spliced_code = String.slice(code, 0..(prefix_len - 1))

    spliced_code
  end
end
