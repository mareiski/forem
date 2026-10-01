class EnablePostgisExtension < ActiveRecord::Migration[7.0]
  def up
    # Enable PostGIS extension for spatial queries
    # Use execute instead of enable_extension to avoid issues with older Rails versions
    # and to provide better error messages
    begin
      safety_assured { execute "CREATE EXTENSION IF NOT EXISTS postgis;" }
      safety_assured { execute "CREATE EXTENSION IF NOT EXISTS postgis_topology;" }
    rescue StandardError => e
      # If PostGIS extension is not available, try to install it
      # This can happen if the PostgreSQL image doesn't have PostGIS pre-installed
      if e.message.include?("postgis.control")
        raise "PostGIS extension is not available. Please ensure you're using a PostGIS-enabled PostgreSQL image (e.g., postgis/postgis:13-3.3-alpine)"
      else
        raise
      end
    end
  end
  
  def down
    # Cannot disable PostGIS as other extensions may depend on it
    # Just log that we're not removing it
    Rails.logger.warn "Not removing PostGIS extension - it may be required by other database objects"
  end
end
