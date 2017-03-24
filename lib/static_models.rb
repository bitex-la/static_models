require "static_models/version"
require "active_support"
require "active_support/inflector"

module StaticModels
  module Model
    extend ActiveSupport::Concern

    included do |i|
      cattr_accessor :values

      def initialize(id, code, *args)
        self.id = id
        self.code = code
        unless args.empty?
          args.first.each{|name,value| send("#{name}=", value) }
        end
      end

      def to_s; code.to_s; end
      def to_i; id; end
      def name; code; end
    end

    class_methods do
      def static_models(new_values)
        attr_accessor :id, :code

        self.values = {}
        new_values.each do |k,v|
          unless k.is_a?(Integer)
            raise TypeError.new("Expected Integer for keys, found #{k.class}")
          end

          if v.is_a?(Array)
            unless v.size == 2 && v.first.is_a?(Symbol) && v.last.is_a?(Hash)
              raise TypeError.new("Expected [Symbol, Hash] found #{v.class}") 
            end
            attr_accessor *v.last.keys
          else
            unless v.is_a?(Symbol)
              raise TypeError.new("Expected Symbol, found #{v.class}")
            end
          end
          item = new(k, *v)
          values[k] = item

          raise DuplicateCodes.new if singleton_methods.include?(item.code)
          define_singleton_method(item.code){ item }
        end
      end

      def find(id)
        values[id.to_i]
      end

      def all
        values.values
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
          module_name = self.class.to_s.split("::")[0..-2].join("::")
          [ opts[:class_name],
            "#{module_name}::#{association.to_s.camelize}",
            association.to_s.camelize,
          ].compact.collect(&:safe_constantize).compact.first
        end

        define_method("#{association}") do
          klass = expected_class || send("#{association}_type").to_s.safe_constantize

          if klass && klass.include?(Model)
            klass.find(send("#{association}_id"))
          elsif defined?(super)
            super()
          end
        end

        define_method("#{association}=") do |value|
          if expected_class && !value.nil? && value.class != expected_class
            raise TypeError.new("Expected #{expected_class} got #{value.class}")
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
      end
    end
  end

  class TypeError < StandardError; end
  class DuplicateCodes < StandardError; end
end
