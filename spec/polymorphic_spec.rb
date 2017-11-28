RSpec.describe "polymorphic associations" do
  before(:all) do
    Tag = new_model(:tag, taggable_id: :integer, taggable_type: :string) do
      include BatchLoaderActiveRecord
      belongs_to :taggable, polymorphic: true
      association_accessor :taggable
    end
    Address = new_model(:address) do
      include BatchLoaderActiveRecord
      has_one :tag, as: :taggable
      association_accessor :tag
    end
    Ticket = new_model(:ticket) do
      include BatchLoaderActiveRecord
      has_many :tags, as: :taggable
      association_accessor :tags
    end
  end

  let(:addresses) { 3.times.map { Address.create } }
  let(:tickets)   { 3.times.map { Ticket.create } }

  before(:each) do
    Tag.delete_all
    Address.delete_all
    Ticket.delete_all
    addresses.each { |address| Tag.create(taggable: address) }
    tickets.each { |ticket| 2.times { Tag.create(taggable: ticket) } }
  end

  describe "fetch a polymorphic association" do
    it "can fetch a polymorphic association from a has_one association" do
      selected = Address.find(addresses.first.id, addresses.third.id)
      expected_tags = Tag.where(taggable_id: selected.map(&:id), taggable_type: 'Address')
      expect(selected.map(&:tag_lazy)).to match_array expected_tags
    end

    it "can fetch a polymorphic association from a has_many association" do
      selected = Ticket.find(tickets.first.id, tickets.third.id)
      expected_tags = Tag.where(taggable_id: selected.map(&:id), taggable_type: 'Ticket')
      expect(selected.map(&:tags_lazy).flatten).to eq expected_tags
    end
  end

  describe "fetching the polymorphs" do
    before(:each) do
      addresses.each { |address| Tag.create(taggable: address) }
      tickets.each { |ticket| 2.times { Tag.create(taggable: ticket) } }
    end

    let(:address_tags) { Tag.where(taggable_id: addresses.map(&:id), taggable_type: 'Address') }
    let(:ticket_tags)  { Tag.where(taggable_id: tickets.map(&:id), taggable_type: 'Ticket') }

    it "can fetch several types from the polymorphic association" do
      tags = address_tags + ticket_tags
      start_query_monitor
      expect(tags.map(&:taggable_lazy).uniq).to match_array(addresses + tickets)
      expect(monitored_queries.length).to eq 2
      stop_query_monitor
    end
  end
end