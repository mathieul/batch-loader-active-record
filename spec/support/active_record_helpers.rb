require 'active_record'
require 'active_support/notifications'
require 'securerandom'

# Establish database connection
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

module ActiveRecordHelpers
  def new_model(create_table, fields = {}, &block)
    table_name = single_table_name(create_table)
    model = Class.new(ActiveRecord::Base) do
      self.table_name = table_name
      connection.create_table(table_name, :force => true) do |table|
        fields.each { |name, type| table.public_send(type, name) }
      end

      singleton_class.class_eval do
        define_method(:name) { "#{create_table.to_s.capitalize}" }
      end
    end
    model.class_eval(&block) if block_given?
    model.reset_column_information
    model
  end

  def create_join_table(*names)
    table_name = join_table_name(names)
    ActiveRecord::Base.connection.create_table(table_name, id: false) do |t|
      names.each { |name| t.column :"#{name}_id", :integer }
    end
  end

  def join_table_name(names)
    names.map(&method(:single_table_name)).sort.join('_')
  end

  def single_table_name(name)
    name.to_s.pluralize
  end

  attr_reader :monitored_queries

  def start_query_monitor
    @monitored_queries = []
    @subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      @monitored_queries << payload[:sql]
    end
  end

  def stop_query_monitor
    return unless @subscriber
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    @subscriber = nil
  end
end

RSpec.configure do |config|
  config.include ActiveRecordHelpers
end
