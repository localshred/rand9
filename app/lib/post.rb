require 'date'

module Marley

  # = Articles
  # Data source is Marley::Configuration.blog_directory (set in <tt>config.yml</tt>)
  class Post
    
    attr_reader :id, :meta, :title, :summary, :published_on, :tags, :body, :body_html, :updated_on, :published, :comments
    
    # comments are referenced via +has_many+ in Comment
    
    def initialize(options={})
      options.each_pair { |key, value| instance_variable_set("@#{key}", value) if self.respond_to? key }
    end
  
    class << self

      def all(options={})
        self.find_all options.merge(:draft => true)
      end
    
      def published(options={})
        self.find_all options.merge(:draft => false)
      end
  
      def [](id, options={})
        self.find_one(id, options)
      end
      alias :find :[] # For +belongs_to+ association in Comment

    end
    
    def tags
      self.meta['tags'] if self.meta && self.meta['tags']
    end

    def permalink
      "/#{id}.html"
    end
            
    private
    
    def self.find_all(options={})
      options[:except] ||= ['body', 'body_html']
      posts = []
      self.extract_posts_from_directory(options).each do |file|
        attributes = self.extract_post_info_from(file, options)
        attributes.merge!( :comments => Marley::Comment.find_all_by_post_id(attributes[:id], :select => ['id'], :conditions => { :spam => false }) )
        posts << self.new( attributes )
      end
      return posts.reverse
    end
    
    def self.find_one(id, options={})
      options.merge!( {:draft => true} ) if Sinatra::Application.environment == :development
      directory = self.load_directories_with_posts(options).select { |dir| dir =~ Regexp.new("\\d\\d\\d\-#{Regexp.escape(id)}(.draft)?\$") }.first
      return if directory.nil? or !File.exist?(directory)
      file = Dir["#{directory}/*.markdown"].first
      self.new( self.extract_post_info_from(file, options).merge( :comments => Marley::Comment.find_all_by_post_id(id, :conditions => { :spam => false }) ) )
    end
    
    # Returns directories in data directory. Default is published only (no <tt>.draft</tt> in name)
    def self.load_directories_with_posts(options={})
      if options[:draft]
        Dir[File.join(Configuration.blog_directory, '*')].select { |dir| File.directory?(dir)  }.sort
      else
        Dir[File.join(Configuration.blog_directory, '*')].select { |dir| File.directory?(dir) and not dir.include?('.draft')  }.sort
      end
    end
    
    # Loads all directories in data directory and returns first <tt>.markdown</tt> file in each one
    def self.extract_posts_from_directory(options={})
      self.load_directories_with_posts(options).collect { |dir| Dir["#{dir}/*.markdown"].first }.compact
    end
    
    def self.extract_post_info_from(file, options={})
      raise ArgumentError, "#{file} is not a readable file" unless File.exist?(file) and File.readable?(file)
      options[:except] ||= []
      options[:only]   ||= Marley::Post.instance_methods # FIXME: Refaktorovat!!
      dirname       = File.dirname(file).split('/').last
      file_content  = File.read(file)
      meta_content  = file_content.slice!( self.regexp[:meta] )
      body          = file_content.strip
      post          = Hash.new

      post[:id] = dirname.sub(self.regexp[:id], '\1').sub(/\.draft$/, '')
      post[:meta] = (meta_content) ? YAML::load(meta_content.scan(self.regexp[:meta]).to_s) : {}
      post[:title] = post[:meta]["title"].strip
      post[:published_on] = Time.parse(post[:meta]["published-on"].strip) if self.use_option?('published_on', options)
      post[:summary] = RDiscount::new( post[:meta]["summary"] ).to_html if self.use_option?('summary', options) && post[:meta]["summary"]
      post[:tags] = post[:meta]["tags"].sort! if self.use_option?('tags', options)
      post[:body] = body if self.use_option?('body', options)
      post[:body_html] = RDiscount::new( body ).to_html if self.use_option?('body_html', options)
      post[:updated_on] = File.mtime(file) if self.use_option?('updated_on', options)
      post[:published] = !dirname.match(/\.draft$/) if self.use_option?('published', options)
      return post
    end
    
    def self.regexp
      {
        :id    => /^\d{0,4}-{0,1}(.*)$/,
        :meta  => /^\{\{\n(.*)\}\}\n$/mi # Multiline Regexp 
      } 
    end
    
    def self.use_option?(opt, options)
      (!options[:except].include?(opt) || options[:only].include?(opt))
    end
  
  end

end
