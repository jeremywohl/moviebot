Sequel.migration do
  change do
    add_column :movies, :created_at, DateTime
    add_column :movies, :updated_at, DateTime
  end
end
