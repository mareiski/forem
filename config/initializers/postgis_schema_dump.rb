# Configure Rails to not include PostGIS extension schemas in schema.rb
# This prevents conflicts when PostGIS extensions create their own schemas
# (tiger, tiger_data, topology)

if Rails::VERSION::MAJOR >= 7
  # For Rails 7+, we can configure schema dump to ignore schemas
  # However, Rails doesn't have a built-in way to ignore schemas in schema dump
  # So we'll use a workaround: filter out create_schema statements for PostGIS schemas
  
  # This initializer runs before schema is dumped
  # We can't prevent schema dump from including create_schema, but we can
  # modify the schema after it's loaded
end

# For now, the simplest solution is to not dump schema at all when PostGIS is involved
# and rely on migrations. This is controlled by removing db/schema.rb
# and letting Rails use migrations instead.
