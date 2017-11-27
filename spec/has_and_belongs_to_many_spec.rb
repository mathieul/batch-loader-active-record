RSpec.describe "lazy has_and_belongs_to_many associations" do
  before(:all) do
    role_table, user_table = create_join_table :role, :user
    User = new_model(:user, table_name: user_table) do
      include BatchLoaderActiveRecord
      has_and_belongs_to_many :roles
      association_accessor :roles
    end
    Role = new_model(:role, table_name: role_table, enabled: :boolean) do
      scope :enabled, -> { where(enabled: true) }
    end
  end

  let(:admin)    { Role.create(enabled: true) }
  let(:agent)    { Role.create(enabled: true) }
  let(:reporter) { Role.create(enabled: false) }
  let(:jane)     { User.create }
  let(:joe)      { User.create }

  before(:each) do
    User.delete_all
    Role.delete_all
    [admin, reporter].each { |role| jane.roles << role }
    joe.roles << agent
  end

  after(:each) { stop_query_monitor }

  it "runs 1 query per object to query regular relationship" do
    start_query_monitor
    User.find(jane.id, joe.id).each(&:roles)
    expect(jane.roles).to eq [admin, reporter]
    expect(joe.roles).to eq [agent]
    expect(monitored_queries.length).to eq (1 + 2)
  end

  it "runs 1 query for all objects to query lazy relationship" do
    start_query_monitor
    [jane, joe].each(&:roles_lazy)
    expect(jane.roles_lazy).to eq [admin, reporter]
    expect(joe.roles_lazy).to eq [agent]
    expect(monitored_queries.length).to eq 1
  end

  it "can pass a scope to specify dynamic association conditions" do
    expect(jane.roles_lazy(Role.enabled)).to eq [admin]
    expect(joe.roles_lazy(Role.enabled)).to eq [agent]
  end

  it "can use a 1-liner to declare an association and generate a lazy accessor" do
    role_table, user_table = create_join_table :person, :quality
    Person = new_model(:person, table_name: user_table) do
      include BatchLoaderActiveRecord
      has_and_belongs_to_many_lazy :qualities
    end
    Quality = new_model(:quality, table_name: role_table)

    strong, smart = 2.times.map { Quality.create }
    lizzy = Person.create
    lizzy.qualities << smart
    expect(lizzy.qualities_lazy).to eq [smart]
  end
end