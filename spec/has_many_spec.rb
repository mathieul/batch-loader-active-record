RSpec.describe "lazy has_many associations" do
  after(:each) { stop_query_monitor }

  describe "has_many_lazy" do
    before(:all) do
      Contact = new_model(:contact) do
        include BatchLoaderActiveRecord
        has_many_lazy :phone_numbers
        has_many_lazy :us_phone_numbers, -> { usa }, class_name: 'PhoneNumber', foreign_key: 'contact_id'
      end
      PhoneNumber = new_model(:phone_number, contact_id: :integer, enabled: :boolean, country_code: :integer) do
        scope :enabled, -> { where(enabled: true) }
        scope :usa, -> { where(country_code: 1) }
      end
    end

    let(:created_phone_numbers) { [] }
    let(:contacts) {
      3.times.map do
        Contact.create.tap do |contact|
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id, enabled: true, country_code: 1)
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id, enabled: false, country_code: 1)
        end
      end
    }

    before(:each) do
      Contact.delete_all
      PhoneNumber.delete_all
      contacts
    end

    it "runs 1 query per object to fetch children with regular relationship" do
      start_query_monitor
      phone_numbers = Contact.find(*contacts.map(&:id)).map(&:phone_numbers).flatten
      expect(phone_numbers).to eq created_phone_numbers
      expect(monitored_queries.length).to eq (1 + 3)
    end

    it "runs 1 query to fetch all children with lazy relationship" do
      start_query_monitor
      phone_numbers = Contact.find(*contacts.map(&:id)).map(&:phone_numbers_lazy).flatten
      expect(phone_numbers).to eq created_phone_numbers
      expect(monitored_queries.length).to eq (1 + 1)
    end

    it "can have a scope" do
      phone_numbers = PhoneNumber.first(4)
      phone_numbers.first.update!(country_code: 33)
      phone_numbers.fourth.update!(country_code: 44)
      contacts = Contact.find(*phone_numbers.map(&:contact_id).uniq)
      us_numbers = contacts.map(&:us_phone_numbers_lazy).flatten
      expect(us_numbers).to eq [phone_numbers.second, phone_numbers.third]
    end

    it "can pass a scope to specify children conditions" do
      enabled_phone_numbers = created_phone_numbers.select(&:enabled?)
      start_query_monitor
      phone_numbers = Contact
        .find(*contacts.map(&:id))
        .map { |contact| contact.phone_numbers_lazy(PhoneNumber.enabled) }
        .flatten

      expect(phone_numbers).to eq enabled_phone_numbers
      expect(monitored_queries.length).to eq (1 + 1)
    end

    it "raises an error if has_many association is inverse of a polymorphic association" do
      expect {
        new_model(:agent) do
          include BatchLoaderActiveRecord
          has_many_lazy :calls, as: :owner
        end
      }.to raise_error(NotImplementedError)
    end

    it "can decouple describing the relationship and making it lazy" do
      EmailAddress = new_model(:EmailAddress, contact_id: :integer)
      Contact.instance_eval do
        has_many :email_addresses
        association_accessor :email_addresses
      end
      email_addresses = []
      contacts = 2.times.map do
        Contact.create.tap do |contact|
          email_addresses << EmailAddress.create(contact_id: contact.id)
          email_addresses << EmailAddress.create(contact_id: contact.id)
        end
      end
      expect(Contact.find(*contacts.map(&:id)).map(&:email_addresses_lazy).flatten).to eq email_addresses
    end
  end

  describe "has_many_lazy through: ..." do
    before(:all) do
      Agent = new_model(:agent) do
        include BatchLoaderActiveRecord
        has_many :phones
        has_many_lazy :providers, through: :phones
      end
      Phone = new_model(:phone, agent_id: :integer) do
        has_many :calls
        has_many :providers, through: :calls
      end
      Call = new_model(:call, phone_id: :integer, provider_id: :integer) do
        belongs_to :provider
      end
      Provider = new_model(:provider, enabled: :boolean, status: :string) do
        scope :enabled, -> { where(enabled: true) }
      end
    end

    let(:all_agents) {
      3.times.map do
        Agent.create.tap do |agent|
          [true, false].each do |enabled|
            phone_number = Phone.create(agent_id: agent.id)
            provider = Provider.create(enabled: enabled)
            Call.create(phone_id: phone_number.id, provider_id: provider.id)
          end
        end
      end
    }
    let(:agents)    { [all_agents.first, all_agents.last] }
    let(:providers) { agents.flat_map(&:phones).flat_map(&:calls).flat_map(&:provider) }

    before(:each) do
      Call.delete_all
      Provider.delete_all
      Phone.delete_all
      Agent.delete_all
      providers
    end

    it "runs 1 query per object to fetch children with regular relationship" do
      start_query_monitor
      providers_fetched = Agent.find(*agents.map(&:id)).map(&:providers).flatten
      expect(providers_fetched).to eq providers
      expect(monitored_queries.length).to eq (1 + 2)
    end

    it "runs 1 query for all the owners to fetch with lazy relationship" do
      start_query_monitor
      providers_fetched = Agent.find(*agents.map(&:id)).map(&:providers_lazy).flatten
      expect(providers_fetched).to eq providers
      expect(monitored_queries.length).to eq (1 + 1)
    end

    it "can pass a scope to specify children conditions" do
      enabled_providers = providers.select(&:enabled?)
      start_query_monitor
      providers_fetched = Agent
        .find(*agents.map(&:id))
        .map { |agent| agent.providers_lazy(Provider.enabled) }
        .flatten

      expect(providers_fetched).to eq enabled_providers
      expect(monitored_queries.length).to eq (1 + 1)
    end
  end
end