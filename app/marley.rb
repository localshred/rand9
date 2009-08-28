MARLEY_ROOT = File.join(File.expand_path(File.dirname(__FILE__)), '..') unless defined?(MARLEY_ROOT)
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'vendor')

require 'rubygems'
require 'ftools'
require 'yaml'
require 'sinatra'
require 'activerecord'
require 'rdiscount'
require 'akismetor'
require 'githubber'

def load_or_require(file)
  (Sinatra::Application.environment == :development) ? load(file) : require(file)
end

%w{
configuration
post
comment
}.each { |f| load_or_require File.join(File.dirname(__FILE__), 'lib', "#{f}.rb") }

# -----------------------------------------------------------------------------

configure do
  # Establish database connection
  ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => File.join(Marley::Configuration.blog_directory, 'comments.db')
  )
  # Set paths to views and public
  set :views  => Marley::Configuration.theme.views.to_s
  set :public => Marley::Configuration.theme.public.to_s
end

configure :development, :production do
  # Create database and schema for comments if not present
  unless Marley::Comment.table_exists?
    puts "* Creating comments SQLite database in #{Marley::Configuration.blog_directory}/comments.db"
    load( File.join( MARLEY_ROOT, 'config', 'db_create_comments.rb' ) )
  end
end

configure :production do
  not_found { not_found }
  error     { error }
end

helpers do
  
  include Rack::Utils
  alias_method :h, :escape_html

  def markup(string)
    RDiscount::new(string).to_html
  end
  
  def human_date(datetime, options={})
    format = '%d %B, %Y'
    format += ' at %H:%M:%S' if options.include?(:long)
    # datetime.strftime(format).gsub(/ 0(\d{1})/, ' \1')
    datetime.strftime(format)
  end

  def rfc_date(datetime)
    datetime.strftime("%Y-%m-%dT%H:%M:%SZ") # 2003-12-13T18:30:02Z
  end

  def hostname
    (request.env['HTTP_X_FORWARDED_SERVER'] =~ /[a-z]*/) ? request.env['HTTP_X_FORWARDED_SERVER'] : request.env['HTTP_HOST']
  end

  def not_found
    File.read( File.join( Sinatra::Application.public, '404.html') )
  end

  def error
    File.read( File.join( Sinatra::Application.public, '500.html') )
  end

  def config
    Marley::Configuration
  end

  def revision
    Marley::Configuration.revision || nil
  end

  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Marley Administration") and \
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?
  end

  def authorized?
    return false unless Marley::Configuration.admin.username && Marley::Configuration.admin.password
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [Marley::Configuration.admin.username, Marley::Configuration.admin.password]
  end
  
  def rand9text(long=false)
    "rand9"+(long ? " Technologies" : "")
  end
  
  def nice_time(old_time)
    diff = (Time.now - old_time).to_i
    if diff < 10 then
      result = 'just a moment ago'
    elsif diff < 60 then
      result = 'less than a minute ago'
    elsif diff < 60 * 1.3  then
      result = "1 minute ago"
    elsif diff < 60 * 50  then
      result = "#{(diff / 60).to_i} minutes ago"
    elsif diff < 60  * 60  * 2 then
      result = 'about 1 hour ago'
    elsif diff < 60  * 60 * (24 / 1.02) then
      result = "about #{(diff / 60 / 60 * 1.02).to_i} hours ago"
    else
      result = old_time.strftime("%H:%M %p %B %d, %Y")
    end
    result
  end
  
  def nice_date(old_date)
    diff = (Date.today - old_date).to_i
    if diff == 0
      result = 'Today'
    elsif diff == 1
      result = "Yesterday"
    elsif diff <= 7
      result = "#{diff} days ago"
    elsif diff <= 30
      result = "#{(diff/7).to_i} weeks ago"
    elsif diff <= 365
      result = "#{(diff/12).to_i} months ago"
    elsif diff > 365
      result = "#{(diff/365).to_i}+ years ago"
    end
    result
  end
  
  # checks to see if the request_path starts with the nav_path 
  def is_cur_nav?(nav_path=nil)
    ((nav_path.nil? && request.env["REQUEST_PATH"] == "/") || (!nav_path.nil? && request.env["REQUEST_PATH"].starts_with?(nav_path)))
  end # def is_cur_nav?
  
  def blog_path
    "/#{Marley::Configuration.blog.pathname}"
  end
  
  def projects_path
    "/projects"
  end
  
  def post_path(post)
    if post.is_a?(Marley::Post)
      post_path = post.id
    else
      post_path = post
    end
    "#{blog_path}/#{post_path}"
  end
  
  def project_path(project)
    "#{projects_path}/#{project[:id]}"
  end

end

# -----------------------------------------------------------------------------

# Redirect old links to posts
get '/:post_id.html*' do
  redirect "#{post_path(params[:post_id].to_s)}#{params[:splat].to_s}"
end

# Home page
get '/' do
  if Sinatra::Application.environment == :development
    @post = Marley::Post.all.first
  else
    @post = Marley::Post.published.first
  end
  @project = {
    :id => "",
    :title => "Consultation for Mongol Horde Applications",
    :completed_on => "2009-05-23 00:00:00"
  }
  
  @page_title = "#{config.site.title} :: We build usable web applications"
  erb :home
end

# Articles list index (blog home)
get "/#{Marley::Configuration.blog.pathname}/?" do
  if Sinatra::Application.environment == :development
    @posts = Marley::Post.all
  else
    @posts = Marley::Post.published
  end
  
  @page_title = "#{Marley::Configuration.blog.title}"
  erb :'blog/index'
end

# Blog articles feed
get "/#{Marley::Configuration.blog.pathname}/feed" do
  @posts = Marley::Post.published
  last_modified( @posts.first.updated_on ) rescue nil    # Conditinal GET, send 304 if not modified
  builder :'blog/index'
end

# Blog articles comments feed
get "/#{Marley::Configuration.blog.pathname}/feed/comments" do
  @comments = Marley::Comment.recent.ham
  last_modified( @comments.first.created_at ) rescue nil # Conditinal GET, send 304 if not modified
  builder :'blog/comments'
end

# Alias path for post comments
get "/#{Marley::Configuration.blog.pathname}/:post_id/comments" do
  redirect "#{post_path(params[:post_id].to_s)}\#comments"
end

# Post request to create a new comment
post "/#{Marley::Configuration.blog.pathname}/:post_id/comments" do
  @post = Marley::Post[ params[:post_id] ]
  throw :halt, [404, not_found ] unless @post
  params.merge!( {
      :ip         => request.env['REMOTE_ADDR'].to_s,
      :user_agent => request.env['HTTP_USER_AGENT'].to_s,
      :referrer   => request.env['REFERER'].to_s,
      :permalink  => "#{hostname}#{@post.permalink}"
  } )
  @comment = Marley::Comment.create( params )
  if @comment.valid?
    # TODO send an email here
    # TODO add "keep me informed of follow up comments"
    redirect "#{post_path(params[:post_id].to_s)}?thank_you=#comment_#{@comment.id}"
  else
    @page_title = "#{@post.title} #{Marley::Configuration.blog.name}"
    erb :'blog/post'
  end
end

# Deleting a post comment
delete "/#{Marley::Configuration.blog.pathname}/admin/:post_id/spam" do
  protected!
  @post = Marley::Post[ params[:post_id] ]
  throw :halt, [404, not_found ] unless @post
  params.merge!( {
      :ip         => request.env['REMOTE_ADDR'].to_s,
      :user_agent => request.env['HTTP_USER_AGENT'].to_s,
      :referrer   => request.env['REFERER'].to_s,
      :permalink  => "#{hostname}#{@post.permalink}"
  } )
  spam_ids = params[:spam_comment_ids].is_a?(Array) ? params[:spam_comment_ids] : [ params[:spam_comment_ids] ]
  @comments = Marley::Comment.find( spam_ids )
  @comments.each do |comment|
    # comment.report_as_spam if Sinatra::Application.production?
    comment.destroy
  end
  redirect "#{@post.permalink}?spam_deleted=#{@comments.size}#comments"
end

# Post comments feed
get "/#{Marley::Configuration.blog.pathname}/:post_id/feed" do
  @post = Marley::Post[ params[:post_id] ]
  throw :halt, [404, not_found ] unless @post
  last_modified( @post.comments.last.created_at ) if @post.comments.last # Conditinal GET, send 304 if not modified
  builder :'blog/post'
end

# Sending a file? I have no idea why you would want this
get "/#{Marley::Configuration.blog.pathname}/:post_id/*" do
  file = params[:splat].to_s.split('/').last
  redirect post_path(params[:post_id].to_s) unless file
  send_file( Marley::Configuration.blog_directory_path.join(params[:post_id], file), :disposition => 'inline' )
end

# Main post path, also handles admin requests to manage the post comments
get "/#{Marley::Configuration.blog.pathname}/*?/?:post_id" do
  # redirect post_path(params[:post_id].to_s) unless params[:splat].first == '' || params[:splat].first == 'admin'
  # protected! if params[:splat].first == 'admin'
  protected! if request.env["REQUEST_PATH"] =~ /\/admin\//i
  @post = Marley::Post[ params[:post_id] ]
  throw :halt, [404, not_found ] unless @post
  @page_title = "#{@post.title} #{Marley::Configuration.blog.name}"
  erb :'blog/post'
end

# Supposedly a post commit hook that is called from github
post '/sync' do
  puts "!!====!!"
  puts "!!SYNC!!"
  puts "!!====!!"
  throw :halt, 404 and return if not Marley::Configuration.github_token or Marley::Configuration.github_token.nil?
  puts "!!past first throw!!"
  unless params[:token] && params[:token] == Marley::Configuration.github_token
    puts "!!you did wrong... 500!!"
    throw :halt, [500, "You did wrong.\n"] and return
  else
    # Synchronize articles in data directory to Github repo
    puts "!!synchronizing!!"
    out = system "cd #{Marley::Configuration.data_directory}; git pull origin master"
    puts "!!system said '#{out}'!!"
  end
end

# Projects list index
get '/projects/?' do
  @page_title = "#{config.site.title} :: Projects"
  erb :'projects/index'
end

# Contact form
get '/contact/?' do
  @page_title = "#{config.site.title} :: Contact"
  erb :contact
end
