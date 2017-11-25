module BatchLoaderActiveRecord
  class AssociationManager
    attr_reader :model, :reflection

    def initialize(model:, reflection:)
      @model = model
      @reflection = reflection
      assert_not_polymorphic
    end

    def batch_key
      [model.table_name, reflection.name]
    end

    def accessor_name
      :"#{reflection.name}_lazy"
    end

    def belongs_to_batch_loader(instance)
      foreign_key_value = instance.send(reflection.foreign_key) or return nil
      BatchLoader.for(foreign_key_value).batch(key: batch_key) do |foreign_key_values, loader|
        target_scope.where(id: foreign_key_values).each { |instance| loader.call(instance.id, instance) }
      end
    end

    private

    def target_scope
      @target_scope ||= if reflection.scope.nil?
        reflection.klass
      else
        reflection.klass.instance_eval(&reflection.scope)
      end
    end

    def assert_not_polymorphic
      if reflection.polymorphic? || reflection.options.has_key?(:as) || reflection.options.has_key?(:source_type)
        raise NotImplementedError, "polymorphic associations are not yet supported (#{reflection.name})"
      end
    end
  end
end