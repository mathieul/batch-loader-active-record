module BatchLoaderActiveRecord
  class AssociationManager
    attr_reader :model, :reflection

    def initialize(model:, reflection:)
      @model = model
      @reflection = reflection
      assert_not_polymorphic
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

    def has_one_to_batch_loader(instance)
      BatchLoader.for(instance.id).batch(key: batch_key) do |model_ids, loader|
        target_scope.where(reflection.foreign_key => model_ids).each do |instance|
          loader.call(instance.public_send(reflection.foreign_key), instance)
        end
      end
    end

    def has_many_to_batch_loader(instance, instance_scope)
      custom_key = batch_key
      custom_key += [instance_scope.to_sql.hash] unless instance_scope.nil?
      BatchLoader.for(instance.id).batch(default_value: [], key: custom_key) do |model_ids, loader|
        relation = if instance_scope.nil?
          target_scope
        else
          target_scope.instance_eval { instance_scope }
        end
        if reflection.through_reflection?
          instances = fetch_for_model_ids(model_ids, relation: relation)
          instances.each do |instance|
            loader.call(instance.public_send(:_instance_id)) { |value| value << instance }
          end
        else
          relation.where(reflection.foreign_key => model_ids).each do |instance|
            loader.call(instance.public_send(reflection.foreign_key)) { |value| value << instance }
          end
        end
      end
    end

    def has_and_belongs_to_many_to_batch_loader(instance)
      BatchLoader.for(instance.id).batch(default_value: [], key: batch_key) do |model_ids, loader|
        target_scope
          .joins(habtm_join(reflection))
          .where("#{reflection.join_table}.#{reflection.foreign_key} IN (?)", model_ids)
          .each do |instance|
            loader.call(instance.public_send(reflection.active_record.primary_key)) do |value|
              value << instance
            end
          end
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

    def batch_key
      @batch_key ||= [model.table_name, reflection.name].freeze
    end

    def assert_not_polymorphic
      if reflection.polymorphic? || reflection.options.has_key?(:as) || reflection.options.has_key?(:source_type)
        raise NotImplementedError, "polymorphic associations are not yet supported (#{reflection.name})"
      end
    end

    def fetch_for_model_ids(ids, relation:)
      instance_id_path = "#{reflection.active_record.table_name}.#{reflection.active_record.primary_key}"
      model_class = reflection.active_record
      reflections = reflection_chain(reflection)
      join_strings = [reflection_join(reflections.first, relation)]
      reflections.each_cons(2) do |previous, current|
        join_strings << reflection_join(current, previous.active_record)
      end
      select_relation = join_strings.reduce(relation) do |select_relation, join_string|
        select_relation.joins(join_string)
      end
      select_relation
        .where("#{model_class.table_name}.#{model_class.primary_key} IN (?)", ids)
        .select("#{relation.table_name}.*, #{instance_id_path} AS _instance_id")
    end

    def reflection_chain(reflection)
      reflections = [reflection]
      begin
        previous   = reflection
        reflection = previous.source_reflection
        if reflection && reflection != previous
          reflections << reflection
        else
          reflection = nil
        end
      end while reflection
      reflections.reverse
    end

    def reflection_join(orig_reflection, model_class)
      reflection = orig_reflection.through_reflection? ? orig_reflection.through_reflection : orig_reflection
      id_path = id_path_for(reflection, model_class)
      table_name = reflection.active_record.table_name
      id_column = reflection.belongs_to? ? reflection.foreign_key : reflection.active_record.primary_key
      "INNER JOIN #{table_name} ON #{table_name}.#{id_column} = #{id_path}"
    end

    def id_path_for(reflection, model_class)
      id_column = if reflection.belongs_to?
        model_class.primary_key
      else
        reflection.foreign_key
      end
      "#{model_class.table_name}.#{id_column}"
    end

    def habtm_join(reflection)
      <<~SQL
        INNER JOIN #{reflection.join_table}
                ON #{reflection.join_table}.#{reflection.association_foreign_key} =
                   #{reflection.klass.table_name}.#{reflection.active_record.primary_key}
      SQL
    end
  end
end