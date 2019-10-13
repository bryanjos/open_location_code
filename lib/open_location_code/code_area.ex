defmodule OpenLocationCode.CodeArea do
  @moduledoc """
  Contains coordinates of a decoded Open Location Code.
  The coordinates include the latitude and longitude of the lower left and
  upper right corners and the center of the bounding box for the area the
  code represents.
  """

  @type t :: %OpenLocationCode.CodeArea{
          south_latitude: number(),
          west_longitude: number(),
          latitude_height: number(),
          longitude_width: number(),
          latitude_center: number(),
          longitude_center: number(),
          code_length: number()
        }
  defstruct [
    :south_latitude,
    :west_longitude,
    :latitude_height,
    :longitude_width,
    :latitude_center,
    :longitude_center,
    :code_length
  ]
end
