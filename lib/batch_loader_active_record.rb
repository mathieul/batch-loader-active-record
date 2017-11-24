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
        reflect = reflections.values.last
        assert_not_polymorphic(reflect)
        batch_key = [table_name, reflect.name]
        assoc_scope = if reflect.scope.nil?
          reflect.klass
        else
          reflect.klass.instance_eval(&reflect.scope)
        end
        define_method(:"#{reflect.name}_lazy") do
          foreign_key_value = send(reflect.foreign_key) or return nil
          BatchLoader.for(foreign_key_value).batch(key: batch_key) do |foreign_key_values, loader|
            assoc_scope.where(id: foreign_key_values).each { |instance| loader.call(instance.id, instance) }
          end
        end
      end
    end

    def has_one_lazy(*args)
      has_one(*args).tap do |reflections|
        reflect = reflections.values.last
        assert_not_polymorphic(reflect)
        assert_no_scope(reflect)
        batch_key = [table_name, reflect.name]
        define_method(:"#{reflect.name}_lazy") do
          BatchLoader.for(id).batch(key: batch_key) do |model_ids, loader|
            reflect.klass.where(reflect.foreign_key => model_ids).each do |instance|
              loader.call(instance.public_send(reflect.foreign_key), instance)
            end
          end
        end
      end
    end

    def has_many_lazy(*args)
      has_many(*args).tap do |reflections|
        reflect = reflections.values.last
        assert_not_polymorphic(reflect)
        assert_no_scope(reflect)
        base_key = [table_name, reflect.name]
        define_method(:"#{reflect.name}_lazy") do |instance_scope = nil|
          batch_key = base_key
          batch_key += [instance_scope.to_sql.hash] unless instance_scope.nil?
          BatchLoader.for(id).batch(default_value: [], key: batch_key) do |model_ids, loader|
            relation = instance_scope || reflect.klass
            if reflect.through_reflection?
              instances = self.class.fetch_for_model_ids(model_ids, relation: relation, reflection: reflect)
              instances.each do |instance|
                loader.call(instance.public_send(:_instance_id)) { |value| value << instance }
              end
            else
              relation.where(reflect.foreign_key => model_ids).each do |instance|
                loader.call(instance.public_send(reflect.foreign_key)) { |value| value << instance }
              end
            end
          end
        end
      end
    end

    def fetch_for_model_ids(ids, relation:, reflection:)
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

    private

    def assert_not_polymorphic(reflection)
      if reflection.polymorphic? || reflection.options.has_key?(:as) || reflection.options.has_key?(:source_type)
        raise NotImplementedError, "polymorphic associations are not yet supported (#{reflection.name})"
      end
    end

    def assert_no_scope(reflection)
      return if reflection.scope.nil?
      raise NotImplementedError, "association scope is not yet supported (#{reflection.name})"
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
  end
end
