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

    before(:each) do
      Post.delete_all
      Comment.delete_all
    end

    it "runs 1 query per owner to fetch with regular relationship" do
      created_posts = []
      c1, c2, c3 = 3.times.map do
        created_posts << (post = Post.create)
        Comment.create(post: post)
      end
      start_query_monitor
      posts = Comment.find(c1.id, c2.id, c3.id).map(&:post)
      expect(posts).to eq created_posts
      expect(monitored_queries.length).to eq(1 + 3)
    end

    it "runs 1 query for all the owners to fetch with lazy relationship" do
      created_posts = []
      c1, c2, c3 = 3.times.map do
        created_posts << (post = Post.create)
        Comment.create(post: post)
      end
      start_query_monitor
      posts = Comment.find(c1.id, c2.id, c3.id).map(&:post_lazy)
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
      PhoneNumber = new_model(:phone_number, contact_id: :integer)
    end

    before(:each) do
      Contact.delete_all
      PhoneNumber.delete_all
    end

    it "runs 1 query per object to fetch children with regular relationship" do
      created_phone_numbers = []
      c1, c2, c3 = 3.times.map do
        Contact.create.tap do |contact|
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id)
        end
      end
      start_query_monitor
      phone_numbers = Contact.find(c1.id, c2.id, c3.id).map(&:phone_numbers).flatten
      expect(phone_numbers).to eq created_phone_numbers
      expect(monitored_queries.length).to eq (1 + 3)
    end

    it "runs 1 query to fetch all children with lazy relationship" do
      created_phone_numbers = []
      c1, c2, c3 = 3.times.map do
        Contact.create.tap do |contact|
          created_phone_numbers << PhoneNumber.create(contact_id: contact.id)
        end
      end
      start_query_monitor
      phone_numbers = Contact.find(c1.id, c2.id, c3.id).map(&:phone_numbers_lazy).flatten
      expect(phone_numbers).to eq created_phone_numbers
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

    before(:each) do
      Account.delete_all
      Affiliate.delete_all
    end

    it "runs 1 query per owner to fetch with regular relationship" do
      created_affiliates = []
      a1, a2, a3 = 3.times.map do
        account = Account.create
        Affiliate.create(account_id: account.id).tap(&created_affiliates.method(:push))
      end
      start_query_monitor
      affiliates = Account.find(a1.id, a2.id, a3.id).map(&:affiliate)
      expect(affiliates).to eq created_affiliates
      expect(monitored_queries.length).to eq(1 + 3)
    end

    it "runs 1 query for all the owners to fetch with lazy relationship" do
      created_affiliates = []
      a1, a2, a3 = 3.times.map do
        account = Account.create
        Affiliate.create(account_id: account.id).tap(&created_affiliates.method(:push))
      end
      start_query_monitor
      affiliates = Account.find(a1.id, a2.id, a3.id).map(&:affiliate_lazy)
      expect(affiliates).to eq created_affiliates
      expect(monitored_queries.length).to eq(1 + 1)
    end
  end
end
