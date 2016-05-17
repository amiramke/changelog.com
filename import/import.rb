require "rubygems"
require "bundler/setup"
require "nokogiri"
require "pg"
require "sequel"
require "pry"

class Nokogiri::XML::Element
  def child_with_name name
    self.children.find { |c| c.name == name }
  end
end

class Author
  attr_reader :el
  def initialize(el); @el = el; end
  def email; el.child_with_name("author_email").text; end
  def handle; el.child_with_name("author_login").text; end
  def id; el.child_with_name("author_id").text.to_i; end
  def name; el.child_with_name("author_display_name").text; end
end

class Post
  attr_reader :el
  def initialize(el); @el = el; end
  def author_handle; el.xpath("dc:creator").text; end
  def body; el.xpath("content:encoded").text; end
  def category; el.xpath("category[@domain='category']").text; end
  def podcast?; category == "Podcast"; end
  def published_at; DateTime.parse(el.child_with_name("pubDate").text); end
  def slug; el.child_with_name("post_name").text; end
  def title; el.child_with_name("title").text; end
  def tags; el.xpath("category[@domain='post_tag']").map(&:text); end
end

class Importer
  def db
    @db ||= Sequel.postgres("changelog_dev", host: "localhost")
  end

  def doc
    @doc ||= File.open(File.expand_path(ENV["IMPORT_FILE"])) { |f| Nokogiri::XML(f) }
  rescue
    abort "Must specify valid IMPORT_FILE env var"
  end

  def authors
    @authors ||= doc.xpath("//channel/wp:author").map { |el| Author.new el }
  end

  def posts
    @posts ||= doc.xpath("//channel/item").map { |el| Post.new el }.reject(&:podcast?)
  end

  def import_people
    authors.each do |author|
      handling_data_issues do
        db[:people].insert({
          name: author.name,
          email: author.email,
          handle: author.handle
        }.merge(timestamps))
      end
    end
  end

  def import_posts
    posts.each do |post|
      handling_data_issues do
        author_id = db[:people].where(handle: post.author_handle).first[:id]
        post_id = db[:posts].insert({
          title: post.title,
          slug: post.slug,
          published: true,
          published_at: post.published_at,
          body: post.body,
          author_id: author_id
        }.merge(timestamps))

        post.tags.each do |tag|
          if channel = db[:channels].where(name: tag).first
            db[:post_channels].insert({
              channel_id: channel[:id],
              post_id: post_id
            }.merge(timestamps))
          end
        end
      end
    end
  end

  private

  def timestamps
    {
      inserted_at: Time.now,
      updated_at: Time.now
    }
  end

  def handling_data_issues
    yield
  rescue Sequel::UniqueConstraintViolation
    # next plz
  end
end

importer = Importer.new

importer.import_people
importer.import_posts