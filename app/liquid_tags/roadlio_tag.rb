class RoadlioTag < LiquidTagBase
  PARTIAL = "liquids/roadlio".freeze
  REGISTRY_REGEXP = %r{\Ahttps://(?:www\.)?roadtrip-planen\.de/reise-ansehen/[^\r\n]+}
  VALID_URL_REGEXP = %r{\Ahttps://(?:www\.)?roadtrip-planen\.de/reise-ansehen/[^\r\n]+\z}

  def initialize(_tag_name, input, _parse_context)
    super
    @url = strip_tags(input)
    raise StandardError, I18n.t("liquid_tags.roadlio_tag.invalid_url") unless @url.match?(VALID_URL_REGEXP)
  end

  def render(_context)
    ApplicationController.render(
      partial: PARTIAL,
      locals: { url: @url },
    )
  end
end

Liquid::Template.register_tag("roadlio", RoadlioTag)

UnifiedEmbed.register(RoadlioTag, regexp: RoadlioTag::REGISTRY_REGEXP)