class FixArticleGeodataPostgis < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Ensure PostGIS extension is enabled first
    enable_extension 'postgis' unless extension_enabled?('postgis')
    
    # The geometry column type is fine as-is, but we need to make sure
    # PostGIS is enabled so the type is recognized by the database
    # No need to change the column type itself
  end
end
