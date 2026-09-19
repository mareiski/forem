class RoadtripTag < LiquidTagBase
  PARTIAL = "liquids/roadtrip".freeze
  REGISTRY_REGEXP = %r{\Ahttps://(?:www\.)?roadtrip-planen\.de/reise-ansehen/[^\r\n]+}
  VALID_URL_REGEXP = %r{\Ahttps://(?:www\.)?roadtrip-planen\.de/reise-ansehen/[^\r\n]+\z}

  def initialize(_tag_name, input, _parse_context)
    super
    @url = strip_tags(input)
    raise StandardError, I18n.t("liquid_tags.roadtrip_tag.invalid_url") unless @url.match?(VALID_URL_REGEXP)
  end

  def render(_context)
    ApplicationController.render(
      partial: PARTIAL,
      locals: { url: @url },
    )
  end
end

Liquid::Template.register_tag("roadtrip", RoadtripTag)

UnifiedEmbed.register(RoadtripTag, regexp: RoadtripTag::REGISTRY_REGEXP)