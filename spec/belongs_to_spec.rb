RSpec.describe BatchLoaderActiveRecord do
  before(:all) do
    Post = new_model(:post, published: :boolean) do
      scope :published, -> { where(published: true) }
    end
    Comment = new_model(:comment, post_id: :integer) do
      include BatchLoaderActiveRecord
      belongs_to_lazy :post
      belongs_to_lazy :published_post, -> { published }, class_name: 'Post', foreign_key: 'post_id'
    end
  end

  let(:created_posts) { [] }
  let(:comments) {
    3.times.map do
      created_posts << (post = Post.create(published: false))
      Comment.create!(post: post)
    end
  }

  before(:each) do
    Post.delete_all
    Comment.delete_all
    comments
  end

  context "compare regular and lazy solutions" do
    after(:each) { stop_query_monitor }

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

  it "can have a scope" do
    posts = created_posts.values_at(0, 2)
    posts.first.update!(published: true)
    comments = Comment.where(post_id: posts.map(&:id))
    published_posts = comments.map(&:published_post_lazy)
    expect(published_posts).to eq [posts.first, nil]
  end

  it "raises an error if belongs_to association is polymorphic" do
    expect {
      new_model(:call) do
        include BatchLoaderActiveRecord
        belongs_to_lazy :owner, polymorphic: true
      end
    }.to raise_error(NotImplementedError)
  end

  it "can decouple describing the relationship and making it lazy" do
    CommentAuthor = new_model(:comment_author, comment_id: :integer) do
      include BatchLoaderActiveRecord
      belongs_to :comment
      association_accessor :comment
    end
    comments = []
    authors = 2.times.map do
      comments << (comment = Comment.create)
      CommentAuthor.create(comment: comment)
    end
    expect(CommentAuthor.find(*authors.map(&:id)).map(&:comment_lazy)).to eq comments
  end
end
