class EnsureGeometryColumnIsPostgisType < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # The error "unknown OID 20611: failed to recognize type of 'geometry'" 
    # indicates that PostgreSQL doesn't recognize the geometry type OID.
    # This happens when PostGIS extension wasn't properly enabled when the table was created.
    
    # Ensure PostGIS extension is enabled
    enable_extension 'postgis' unless extension_enabled?('postgis')
    
    # Check if the table exists
    return unless table_exists?(:article_geodata)
    
    # Check if the geometry column exists
    unless column_exists?(:article_geodata, :geometry)
      # Column doesn't exist, add it with correct type
      add_column :article_geodata, :geometry, "geometry(GEOMETRY,4326)"
      add_index :article_geodata, :geometry, using: :gist, name: 'index_article_geodata_on_geometry'
      return
    end
    
    # Column exists - verify it's the correct type
    # Query PostgreSQL directly to get the actual column type
    type_info = execute("SELECT data_type FROM information_schema.columns WHERE table_name = 'article_geodata' AND column_name = 'geometry'").first
    actual_type = type_info&.[]('data_type')&.downcase
    
    # If the type is not geometry, we need to fix it
    unless actual_type&.include?('geometry')
      execute <<~SQL
        -- Backup existing data
        ALTER TABLE article_geodata ADD COLUMN geometry_backup TEXT;
        UPDATE article_geodata SET geometry_backup = geometry::text WHERE geometry IS NOT NULL;
        
        -- Drop the old column
        ALTER TABLE article_geodata DROP COLUMN geometry;
        
        -- Add the column with correct PostGIS type
        ALTER TABLE article_geodata ADD COLUMN geometry geometry(GEOMETRY,4326);
        
        -- Restore data: convert WKT strings back to geometry
        UPDATE article_geodata 
        SET geometry = ST_GeomFromText(geometry_backup, 4326)
        WHERE geometry_backup IS NOT NULL AND geometry_backup != '';
        
        -- Clean up
        ALTER TABLE article_geodata DROP COLUMN geometry_backup;
      SQL
      
      # Recreate the spatial index
      remove_index :article_geodata, :geometry, name: 'index_article_geodata_on_geometry' if index_exists?(:article_geodata, :geometry)
      add_index :article_geodata, :geometry, using: :gist, name: 'index_article_geodata_on_geometry'
    end
    
    # Ensure spatial index exists
    add_index :article_geodata, :geometry, using: :gist, name: 'index_article_geodata_on_geometry' unless index_exists?(:article_geodata, :geometry)
  end
end
