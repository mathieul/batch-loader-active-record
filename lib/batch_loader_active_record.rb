# frozen_string_literal: true

require "batch_loader_active_record/version"
require "batch-loader"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def belongs_to_lazy(*args)
      belongs_to(*args).tap do |reflections|
        assoc = reflections.values.last
        batch_key = [table_name, assoc.name]
        define_method(:"#{assoc.name}_lazy") do
          foreign_key_value = send(assoc.foreign_key) or return nil
          BatchLoader.for(foreign_key_value).batch(key: batch_key) do |foreign_key_values, loader|
            assoc.klass.where(id: foreign_key_values).each { |instance| loader.call(instance.id, instance) }
          end
        end
      end
    end

    def has_one_lazy(*args)
      has_one(*args).tap do |reflections|
        assoc = reflections.values.last
        batch_key = [table_name, assoc.name]
        define_method(:"#{assoc.name}_lazy") do
          BatchLoader.for(id).batch(key: batch_key) do |model_ids, loader|
            assoc.klass.where(assoc.foreign_key => model_ids).each do |instance|
              loader.call(instance.public_send(assoc.foreign_key), instance)
            end
          end
        end
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do |reflections|
        assoc = reflections.values.last
        base_key = [table_name, assoc.name]
        define_method(:"#{assoc.name}_lazy") do |instance_scope = nil|
          batch_key = base_key
          batch_key += [instance_scope.to_sql.hash] unless instance_scope.nil?
          BatchLoader.for(id).batch(default_value: [], key: batch_key) do |model_ids, loader|
            (instance_scope || assoc.klass).where(assoc.foreign_key => model_ids).each do |instance|
              loader.call(instance.public_send(assoc.foreign_key)) { |value| value << instance }
            end
          end
        end
      end
    end
  end
end
