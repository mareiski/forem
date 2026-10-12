require "json"

class CountryGeosearchService
  GEOJSON_PATH = Rails.root.join(
    "app/assets/geo/countries.geojson"
  )

  def initialize
    @countries = JSON.parse(File.read(GEOJSON_PATH))
  end

  def geometry_for_country(country_code)
    code = country_code.to_s.strip.upcase

    feature = @countries.fetch("features").find do |item|
      item.dig("properties", "ISO3166-1-Alpha-2") == code
    end

    raise ActiveRecord::RecordNotFound,
          "Country not found: #{code}" unless feature

    geometry = feature.fetch("geometry")

    unless %w[Polygon MultiPolygon].include?(geometry["type"])
      raise ArgumentError, "Invalid geometry for country: #{code}"
    end

    geometry
  end

  def articles_for_country(country_code, limit: 6, offset: 0)
  geometry = geometry_for_country(country_code)

  GeosearchService.new.intersects_geojson(
    geometry,
    limit: limit,
    offset: offset
  )
end
end