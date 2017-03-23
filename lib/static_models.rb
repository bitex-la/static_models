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

      def to_s
        code.to_s
      end

      def to_i
        id
      end

      def name
        code
      end
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
      def belongs_to_static_model(attr_name, cls=nil)
        cls ||= attr_name.to_s.humanize.constantize

        define_method(attr_name) do
          cls.find(send("#{attr_name}_id"))
        end

        define_method("#{attr_name}=") do |value|
          unless value.nil? || value.is_a?(cls)
            raise TypeError.new("Expected #{cls} got #{value.class}")
          end
          send("#{attr_name}_id=", value && value.id)
        end
      end
    end
  end

  class TypeError < StandardError; end
  class DuplicateCodes < StandardError; end
end
