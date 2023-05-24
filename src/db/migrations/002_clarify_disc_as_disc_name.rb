Sequel.migration do
  change do
    alter_table(:movies) do
      rename_column :disc, :disc_name
    end
  end
end
