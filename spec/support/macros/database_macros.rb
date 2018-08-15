require 'active_record'

module DatabaseMacros
  def setup_database!(opts = {})
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: "static_models_test.sqlite",
      username: 'travis',
      encoding: 'utf8'
    )
    # Silence everything
    ActiveRecord::Base.logger = ActiveRecord::Migration.verbose = false
  end

  def cleanup_database!
    `rm static_models_test.sqlite` if File.exist?('static_models_test.sqlite')
  end

  # Run migrations in the test database
  def run_migration(&block)
    # Create a new migration class
    klass = Class.new(ActiveRecord::Migration[5.0])
    # Create a new `up` that executes the argument
    klass.send(:define_method, :up) { instance_exec(&block) }
    # Create a new instance of it and execute its `up` method
    klass.new.up
  end
end
