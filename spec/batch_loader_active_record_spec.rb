RSpec.describe BatchLoaderActiveRecord do
  after(:each) { stop_query_monitor }

  describe "belongs_to_lazy" do
    before(:all) do
      Post = new_model(:post)
      Comment = new_model(:comment, post_id: :integer) do
        include BatchLoaderActiveRecord
        belongs_to_lazy :post
      end
    end

    let(:created_posts) { [] }
    let(:comments) {
      3.times.map do
        created_posts << (post = Post.create)
        Comment.create!(post: post)
      end
    }

    before(:each) do
      Post.delete_all
      Comment.delete_all
      comments
    end

    it "runs 1 query per owner to fetch with regular relationship" do
      start_query_monitor
      posts = Comment.find(*comments.map(&:id)).map(&:post)
      expect(posts).to eq created_posts
      expect(monitored_queries.length).to eq(1 + 3)
    end

    it "runs 1 query for all the owners to fetch with lazy relationship" do
      start_query_monitor
      posts = Comment.find(*comments.map(&:id)).map(&:post_lazy)
      expect(posts).to eq created_posts
      expect(monitored_queries.length).to eq(1 + 1)
    end
  end

  describe "has_many_lazy" do
    before(:all) do
      Contact = new_model(:contact) do
        include BatchLoaderActiveRecord
        has_many_lazy :phone_numbers
      end
      PhoneNumber = new_model(:phone_number, contact_id: :integer, enabled: :boolean) do
        scope :active, -> { where(enabled: true) }
      end
    end

    let(:created_phone_numbers) { [] }
    let(:contacts) {
      3.times.map do
        Contact.create.tap do |contact|
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id, enabled: true)
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id, enabled: false)
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

    it "can pass a scope to specify children conditions" do
      enabled_phone_numbers = created_phone_numbers.select(&:enabled?)
      start_query_monitor
      phone_numbers = Contact
        .find(*contacts.map(&:id))
        .map { |contact| contact.phone_numbers_lazy(PhoneNumber.active) }
        .flatten

      expect(phone_numbers).to eq enabled_phone_numbers
      expect(monitored_queries.length).to eq (1 + 1)
    end
  end

  describe "has_many_lazy through: ..." do
    it "raises an error as it is not currently supported" do
      expect {
        new_model(:agent) do
          include BatchLoaderActiveRecord
          has_many :phones
          has_many_lazy :calls, through: :phones
        end
      }.to raise_error(NotImplementedError)
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
        belongs_to :agent
        has_many :calls
        has_many :providers, through: :calls
      end
      Call = new_model(:call, phone_id: :integer, provider_id: :integer) do
        belongs_to :phone
        belongs_to :provider
      end
      Provider = new_model(:provider, enabled: :boolean) do
        has_many :calls
        scope :active, -> { where(enabled: true) }
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
        .map { |agent| agent.providers_lazy(Provider.active) }
        .flatten

      expect(providers_fetched).to eq enabled_providers
      expect(monitored_queries.length).to eq (1 + 1)
    end
  end

  describe "has_one_lazy" do
    before(:all) do
      Account = new_model(:account) do
        include BatchLoaderActiveRecord
        has_one_lazy :affiliate
      end
      Affiliate = new_model(:affiliate, account_id: :integer)
    end

    let(:created_accounts) { [] }
    let(:created_affiliates) {
      3.times.map do
        created_accounts << (account = Account.create)
        Affiliate.create(account_id: account.id)
      end
    }

    before(:each) do
      Account.delete_all
      Affiliate.delete_all
      created_affiliates
    end

    it "runs 1 query per owner to fetch with regular relationship" do
      start_query_monitor
      affiliates = Account.find(created_accounts.map(&:id)).map(&:affiliate)
      expect(affiliates).to eq created_affiliates
      expect(monitored_queries.length).to eq(1 + 3)
    end

    it "runs 1 query for all the owners to fetch with lazy relationship" do
      start_query_monitor
      affiliates = Account.find(created_accounts.map(&:id)).map(&:affiliate_lazy)
      expect(affiliates).to eq created_affiliates
      expect(monitored_queries.length).to eq(1 + 1)
    end
  end
end
