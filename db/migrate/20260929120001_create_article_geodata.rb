class CreateArticleGeodata < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    create_table :article_geodata do |t|
      t.references :article, null: false, foreign_key: true, index: { unique: true }
      
      # Store the original GeoJSON data (point or line)
      t.jsonb :geojson_data, null: false
      
      # Store the geometry type (point, linestring, etc.)
      t.string :geometry_type, null: false
      
      # PostGIS geography column for spatial indexing and queries. Use an explicit
      # SQL type because the project does not use activerecord-postgis-adapter.
      t.column :geometry, "geography(Geometry,4326)"
      
      # Metadata about the geodata
      t.string :source_type # e.g., 'custom_endpoint', 'manual_entry'
      t.jsonb :source_metadata
      
      # Bounding box coordinates for quick filtering
      t.float :bounds_min_lon
      t.float :bounds_min_lat
      t.float :bounds_max_lon
      t.float :bounds_max_lat
      
      t.timestamps
    end
    
    # Add spatial index on the geometry column for fast geospatial queries
    add_index :article_geodata, :geometry, using: :gist
    
    # Note: unique index on article_id is already created by t.references with index: { unique: true }
  end
end
