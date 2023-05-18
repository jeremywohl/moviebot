Sequel.migration do
  change do
    create_table(:movies) do
      primary_key :id

      # makemkv fields
      String  :disc
      Integer :track_id
      String  :track_name
      Integer :time  # seconds
      Integer :size  # bytes

      # moviebot fields
      String  :name, null: false
      Integer :year

      # internal fields
      String  :state, null: false, default: 'pending'
      String  :rip_dir
      String  :rip_fn
      String  :encode_fn
      String  :done_fn
    end
  end
end
