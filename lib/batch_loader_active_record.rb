# frozen_string_literal: true

require "batch-loader"
require "batch_loader_active_record/version"
require "batch_loader_active_record/association_manager"

module BatchLoaderActiveRecord
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def belongs_to_lazy(*args)
      belongs_to(*args).tap do |reflections|
        manager = AssociationManager.new(model: self, reflection: reflections.values.last)
        define_method(manager.accessor_name) { manager.belongs_to_batch_loader(self) }
      end
    end

    def association_accessor(name)
      reflection = reflect_on_association(name) or raise "Can't find association #{name.inspect}"
      manager = AssociationManager.new(model: self, reflection: reflection)
      case reflection.macro
      when :belongs_to
        define_method(manager.accessor_name) { manager.belongs_to_batch_loader(self) }
      when :has_one
        define_method(manager.accessor_name) { manager.has_one_to_batch_loader(self) }
      when :has_many
        define_method(manager.accessor_name) do |instance_scope = nil|
          manager.has_many_to_batch_loader(self, instance_scope)
        end
      when :has_and_belongs_to_many
        define_method(manager.accessor_name) { manager.has_and_belongs_to_many_to_batch_loader(self) }
      else
        raise NotImplementedError, "association kind #{reflection.macro.inspect} is not yet supported"
      end
    end

    def has_one_lazy(*args)
      has_one(*args).tap do |reflections|
        manager = AssociationManager.new(model: self, reflection: reflections.values.last)
        define_method(manager.accessor_name) { manager.has_one_to_batch_loader(self) }
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do |reflections|
        manager = AssociationManager.new(model: self, reflection: reflections.values.last)
        define_method(manager.accessor_name) do |instance_scope = nil|
          manager.has_many_to_batch_loader(self, instance_scope)
        end
      end
    end
  end
end
