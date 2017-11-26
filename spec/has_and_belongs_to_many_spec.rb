RSpec.describe "lazy has_and_belongs_to_many associations" do
  before(:all) do
    role_table, user_table = create_join_table :role, :user
    User = new_model(:user, user_table) do
      include BatchLoaderActiveRecord
      has_and_belongs_to_many :roles
      association_accessor :roles
    end
    Role = new_model(:role, role_table)
  end

  let(:admin)    { Role.create }
  let(:agent)    { Role.create }
  let(:reporter) { Role.create }
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
    first, second = User.find(jane.id, joe.id).each(&:roles_lazy)
    expect(first.roles_lazy).to eq [admin, reporter]
    expect(second.roles_lazy).to eq [agent]
    expect(monitored_queries.length).to eq (1 + 1)
  end
end