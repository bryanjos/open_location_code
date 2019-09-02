defmodule OpenLocationCodeTest do
  use ExUnit.Case, async: true
  doctest OpenLocationCode
  use ExUnitProperties

  test "encoding" do
    Path.join([File.cwd() |> elem(1), "test", "test_data", "encoding.csv"])
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(fn
      "#" <> _ -> true
      _ -> false
    end)
    |> Enum.map(fn x -> String.split(x, ",") end)
    |> Enum.map(fn [latitude, longitude, length, expected_code] ->
      [
        Float.parse(latitude) |> elem(0),
        Float.parse(longitude) |> elem(0),
        String.to_integer(length),
        expected_code
      ]
    end)
    |> Enum.map(fn [latitude, longitude, length, expected_code] ->
      assert {:ok, ^expected_code} = OpenLocationCode.encode(latitude, longitude, length)
    end)
  end

  test "decoding" do
    # code,length,latLo,lngLo,latHi,lngHi

    Path.join([File.cwd() |> elem(1), "test", "test_data", "decoding.csv"])
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(fn
      "#" <> _ -> true
      _ -> false
    end)
    |> Enum.map(fn x -> String.split(x, ",") end)
    |> Enum.map(fn [code, length, lat_lo, lng_lo, lat_hi, lng_hi] ->
      [
        code,
        String.to_integer(length),
        Float.parse(lat_lo) |> elem(0),
        Float.parse(lng_lo) |> elem(0),
        Float.parse(lat_hi) |> elem(0),
        Float.parse(lng_hi) |> elem(0)
      ]
    end)
    |> Enum.map(fn [code, _length, lat_lo, lng_lo, _lat_hi, _lng_hi] ->
      assert {:ok, code_area} = OpenLocationCode.decode(code)
      assert_in_delta code_area.south_latitude, lat_lo, 0.1
      assert_in_delta code_area.west_longitude, lng_lo, 0.1
    end)
  end

  test "valid?" do
    Path.join([File.cwd() |> elem(1), "test", "test_data", "validity_tests.csv"])
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(fn
      "#" <> _ -> true
      _ -> false
    end)
    |> Enum.map(fn x -> String.split(x, ",") end)
    |> Enum.map(fn [code, is_valid, is_short, is_full] ->
      [code, is_valid == "true", is_short == "true", is_full == "true"]
    end)
    |> Enum.map(fn [code, is_valid, is_short, is_full] ->
      assert OpenLocationCode.valid?(code) == is_valid
      assert OpenLocationCode.short?(code) == is_short
      assert OpenLocationCode.full?(code) == is_full
    end)
  end

  test "shorten" do
    Path.join([File.cwd() |> elem(1), "test", "test_data", "short_code_tests.csv"])
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(fn
      "#" <> _ -> true
      _ -> false
    end)
    |> Enum.map(fn x -> String.split(x, ",") end)
    |> Enum.map(fn [full_code, lat, lng, short_code, test_type] ->
      [full_code, Float.parse(lat) |> elem(0), Float.parse(lng) |> elem(0), short_code, test_type]
    end)
    |> Enum.each(fn
      [full_code, lat, lng, short_code, "S"] ->
        assert OpenLocationCode.shorten(full_code, lat, lng) == short_code

      [full_code, lat, lng, short_code, "R"] ->
        assert OpenLocationCode.recover_nearest(short_code, lat, lng) == full_code

      [full_code, lat, lng, short_code, "B"] ->
        assert OpenLocationCode.shorten(full_code, lat, lng) == short_code
        assert OpenLocationCode.recover_nearest(short_code, lat, lng) == full_code
    end)
  end

  property "encode and decode back to the correct coordinates" do
    check all(
            latitude <- float(min: -90.0, max: 90.0),
            longitude <- float(min: -180.0, max: 180.0)
          ) do
      {:ok, code} = OpenLocationCode.encode(latitude, longitude)
      {:ok, code_area} = OpenLocationCode.decode(code)

      assert_in_delta code_area.longitude_center, longitude, 0.01
      assert_in_delta code_area.latitude_center, latitude, 0.01
    end
  end
end
