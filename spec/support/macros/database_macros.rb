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
    klass = Class.new(ActiveRecord::Migration)
    # Create a new `up` that executes the argument
    klass.send(:define_method, :up) { instance_exec(&block) }
    # Create a new instance of it and execute its `up` method
    klass.new.up
  end

  def spawn_model(klass_name, parent_klass = ActiveRecord::Base, &block)
    Object.instance_eval { remove_const klass_name } if Object.const_defined?(klass_name)
    Object.const_set(klass_name, Class.new(parent_klass))
    Object.const_get(klass_name).class_eval(&block) if block_given?
  end
end
