Sequel.migration do
  change do
    # encode fields
    add_column :movies, :encode_state,       String, null: false, default: 'pending'
    add_column :movies, :encode_start_time,  Integer  # seconds
    add_column :movies, :encode_cloud_name,  String

    # more metadata
    add_column :movies, :rip_time,           Integer  # seconds
    add_column :movies, :encode_time,        Integer  # seconds
    add_column :movies, :encode_size,        Integer  # bytes
  end
end
