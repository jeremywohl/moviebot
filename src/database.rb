#
# database
#

class Database
  def self.open_and_migrate
    dbpath = File.join(MOVIES_ROOT, '.moviebot.db')
    db = Sequel.sqlite(dbpath)

    Sequel::Model.plugin :validation_helpers
    Sequel::Model.plugin :defaults_setter
    Sequel.extension :migration

    # run migrations
    migrations_path = File.join(File.expand_path(File.dirname(__FILE__)), 'db/migrations')
    Sequel::IntegerMigrator.run(db, migrations_path, use_transactions: true)

    return db
  end
end
