RSpec.describe BatchLoaderActiveRecord do
  before(:all) do
    Account = new_model(:account) do
      include BatchLoaderActiveRecord
      has_one_lazy :affiliate
      has_one_lazy :enabled_affiliate, -> { enabled }, class_name: 'Affiliate', foreign_key: 'account_id'
    end
    Affiliate = new_model(:affiliate, account_id: :integer, enabled: :boolean) do
      scope :enabled, -> { where(enabled: true) }
    end
  end

  let(:created_accounts) { [] }
  let(:created_affiliates) {
    3.times.map do
      created_accounts << (account = Account.create)
      Affiliate.create(account_id: account.id, enabled: true)
    end
  }

  before(:each) do
    Account.delete_all
    Affiliate.delete_all
    created_affiliates
  end

  after(:each) { stop_query_monitor }

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

  it "can have a scope" do
    affiliates = created_affiliates.values_at(0, 2)
    affiliates.first.update!(enabled: false)
    accounts = Account.find(*affiliates.map(&:account_id))
    enabled_affiliates = accounts.map(&:enabled_affiliate_lazy)
    expect(enabled_affiliates).to eq [nil, affiliates.second]
  end

  it "raises an error if has_one association is inverse of a polymorphic association" do
    expect {
      new_model(:agent) do
        include BatchLoaderActiveRecord
        has_one_lazy :profile, as: :profile_owner
      end
    }.to raise_error(NotImplementedError)
  end

  it "can decouple describing the relationship and making it lazy" do
    AccountProfile = new_model(:account_profile, account_id: :integer)
    Account.instance_eval do
      include BatchLoaderActiveRecord
      has_one :account_profile
      association_accessor :account_profile
    end
    accounts = []
    profiles = 2.times.map do
      accounts << (account = Account.create)
      AccountProfile.create(account_id: account.id)
    end
    expect(Account.find(*accounts.map(&:id)).map(&:account_profile_lazy)).to eq profiles
  end
end
