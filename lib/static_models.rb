require "static_models/version"
require "active_support"
require "active_support/inflector"

module StaticModels
  module Model
    extend ActiveSupport::Concern

    included do |i|
      cattr_accessor :values, :primary_key, :code_column
      attr_accessor :attributes

      def initialize(attributes)
        self.attributes = attributes
        attributes.each{|name,value| send("#{name}=", value) }
      end

      def name
        send(self.class.code_column)
      end

      def to_s
        name.to_s
      end

      def to_i
        send(self.class.primary_key)
      end

      # Ugly hack to make this compatible with AR validatinos.
      # It's safe to assume a StaticModel is always valid and never destroyed.
      def marked_for_destruction?
        false
      end

      def valid?
        true
      end

      # For compatibility with AR relations in ActiveAdmin and others.
      # Feel free to override this.
      def self.where(*args)
        all
      end

      def ==(other)
        other.try(:id) == id
      end

      def hash
        "static_model_#{self.class.object_id}_#{id}".freeze.hash
      end

      def eql?(other)
        other == self
      end
    end

    class_methods do
      NumberType = if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.4.0')
        Integer
      else
        Fixnum
      end

      def static_models_dense(table)
        columns = table.first
        hashes = table[1..-1].collect do |row|
          Hash[*columns.zip(row).flatten(1)]
        end

        static_models_hashes columns, hashes
      end

      def static_models_sparse(table)
        table.each do |row|
          expected = row.size == 2 ? [NumberType, Symbol] : [NumberType, Symbol, Hash]

          if row.collect(&:class) != expected
            raise ValueError.new("Invalid row #{row}, expected #{expected}")
          end
        end

        columns = table.select{|r| r.size == 3}
          .collect{|r| r.last.keys }.flatten(1).uniq

        hashes = table.collect{ |r| (r[2] || {}).merge(id: r[0], code: r[1]) }
        static_models_hashes ([:id, :code] + columns), hashes
      end

      def static_models_hashes(columns, hashes)
        unless columns.all?{|c| c.is_a?(Symbol)}
          raise ValueError.new("Table column names must all be Symbols")
        end

        unless hashes.all?{|h| h[:id].is_a?(NumberType)}
          raise ValueError.new("Ids must be integers")
        end

        unless hashes.all?{|h| h[:code].is_a?(Symbol)}
          raise ValueError.new("Codes must be Symbols")
        end

        attr_accessor *columns
        self.primary_key = columns[0]
        self.code_column = columns[1]

        self.values = {}
        hashes.each do |hash|
          item = new(hash)
          values[item.id] = item
          raise ValueError.new if singleton_methods.include?(item.code)
          define_singleton_method(item.code){ item }
        end

        def arel_table
          @arel_table ||= begin
                            table_name = self.to_s.split('::').map(&:underscore).map(&:pluralize).join('_')
                            Arel::Table.new(table_name, type_caster: ::StaticModels::FakeTypeCaster.new)
                          end
        end
      end

      def find(id)
        values[id.to_i] || (raise NotFoundError.new("id #{id} not found"))
      end

      def find_by_code(code)
        all.select{|x| x.code == code.try(:to_sym)}.first
      end

      def all
        values.values
      end

      def codes
        values.values.map(&:code)
      end

      def model_name
        ActiveModel::Name.new(self)
      end
    end
  end

  # When included, it adds a class method that works similar to rails
  # 'belongs_to', but instead of fetching an association it gets a static model.
  module BelongsTo
    extend ActiveSupport::Concern

    class_methods do
      def belongs_to(association, opts = {})
        super(association, opts) if defined?(super)

        expected_class = unless opts[:polymorphic]
          module_name = self.to_s.split("::")[0..-2].join("::")
          [ opts[:class_name],
            "#{module_name}::#{association.to_s.camelize}",
            association.to_s.camelize,
          ].compact.collect(&:safe_constantize).compact.first
        end

        define_method("#{association}") do
          klass = expected_class || send("#{association}_type").to_s.safe_constantize

          if klass && klass.include?(Model) && send("#{association}_id").present?
            klass.find(send("#{association}_id"))
          elsif defined?(super)
            super()
          end
        end

        define_method("#{association}=") do |value|
          if expected_class && !value.nil? && value.class != expected_class
            raise ValueError.new("Expected #{expected_class} got #{value.class}")
          end

          if value.nil? || value.class.include?(Model)
            if opts[:polymorphic]
              # This next line resets the old polymorphic association
              # if it was set to an ActiveRecord::Model. Otherwise
              # ActiveRecord will get confused and ask for our StaticModel's
              # table and a bunch of other things that don't apply.
              super(nil) if defined?(super)
              send("#{association}_type=", value && value.class.name )
            end
            send("#{association}_id=", value && value.id)
          else
            super(value)
          end
        end

        #Adding accesor for code_representation
        define_method("#{association}_code=") do |value|
          if thing = expected_class.find_by_code(value)
            instance_variable_set("@invalid_#{association}_code", nil)
            send("#{association}=", thing)
          else
            instance_variable_set("@invalid_#{association}_code",
              value.try(:to_sym))
          end
        end

        define_method("#{association}_code") do
          send(association).try(:code) ||
            instance_variable_get("@invalid_#{association}_code")
        end
      end
    end
  end

  class FakeTypeCaster
    def type_cast_for_database(_attr_name, value)
      value
    end
  end

  class ValueError < StandardError; end
  class NotFoundError < StandardError; end
end
