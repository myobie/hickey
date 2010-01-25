require 'sinatra/base'
require 'dm-core'
require 'dm-timestamps'
require 'rdiscount'

DataMapper::Logger.new(STDOUT, :info) # :off, :fatal, :error, :warn, :info, :debug
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///Users/#{`whoami`}/Desktop/wiki.db")

class Page
  include DataMapper::Resource
  
  property :id, Serial
  property :slug, String, :length => 255
  property :title, String, :length => 255
  property :body, Text
  property :rendered_body, Text
  property :version, Integer, :default => 0
  property :editor_name, String, :length => 255, :default => "Nobody"
  property :editor_ip, String
  property :created_at, DateTime
  
  before :save, :render_body
  before :save, :next_version
  
  def self.first_for_slug(what)
    first(:slug => what, :order => [:version.desc])
  end
  
  def self.all_for_slug(what)
    all(:slug => what, :order => [:version.asc])
  end
  
protected
  def render_body
    self.rendered_body = RDiscount.new(body || "").to_html
  end
  
  def next_version
    if version.blank? || version == 0
      newest_page = self.class.first_for_slug(slug)
      self.version = newest_page ? newest_page.version + 1 : 1
      self.editor_name = "nobody" if editor_name.blank?
    end
  end
end

class Hickey < Sinatra::Base
  enable :methodoverride, :static, :sessions, :logging
  set :app_file, __FILE__
  set :haml, { :format => :html5 }
  use_in_file_templates!
  alias_method :h, :escape_html
  
  def title
    "#{@page ? "#{@page.title} - " : ""} Hickey Wiki"
  end
  
  def partial(name)
    haml name, :layout => false
  end
  
  def message(what, type = "notice")
    @message = what
    @message_type = type
  end
  
  get "/pages" do
    @pages = repository.adapter.select("SELECT id, slug, title, version FROM pages ORDER BY version DESC")
    haml :pages
  end
  
  get "/pages/:id" do
    repository do
      @page = Page.get(params[:id])
      @pages = Page.all_for_slug(@page.slug)
    
      message "This is an older version (#{@page.version})." if @pages.last != @page
    
      @pages =  (@pages - @page).reverse
      body haml(:page)
    end
  end
  
  get "/pages/:id/edit" do
    @page = Page.get(params[:id])
    haml :edit
  end
  
  post "/pages" do
    @page = Page.new params[:page]
    @page.editor_ip = @env['REMOTE_ADDR']
    
    if @page.save
      redirect @page.slug
    else
      message "There is something wrong with what you submitted.", :error
      haml :edit
    end
  end
  
  delete "/pages/:id" do
    @page = Page.get(params[:id])
    @page.destroy
    
    possible_past_version = Post.first_for_slug(@page.slug)
    
    redirect(possible_past_version ? "/#{possible_past_version.slug}" : "/")
  end
  
  get "*" do
    repository do
      @slug = params["splat"].join("/")
    
      @page = Page.first_for_slug(@slug)
    
      if @page.blank?
        if params["create_new"] == "yes"
          @page = Page.create(:slug => @slug)
        else
          throw :halt, [404, haml(:not_found)]
        end
      end
    
      @pages = (Page.all_for_slug(@slug) - @page).reverse
    
      body haml(:page)
    end
  end
end

__END__

@@ layout
!!!
%html
  %head
    %title= title
    %link(rel="stylesheet" href="/master.css" type="text/css")
  %body
    %ul#links
      %li
        %a(href="/") Homepage
      %li
        %a(href="/pages") All pages
    = partial :message
    = yield
    %script(src="/jquery.min.js")
    %script(src="/application.js")

@@ message
- unless @message.blank?
  #message(class="#{@message_type}")
    %p= @message

@@ page
#content
  = @page.rendered_body
%ul#meta
  %li
    %a(href="/pages/#{@page.id}/edit") Edit this page
  %li= "Last edited by #{@page.editor_name}"
  %li.version
    %em= "(Version: #{@page.version})"
    - unless @pages.blank?
      %ul.versions
        - @pages.each do |page|
          %li
            %a(href="/pages/#{page.id}")= "Version #{page.version}"

@@ pages
#content
  %ul
    - @pages.each do |page|
      %li
        %a(href="#{page.slug}")= "#{page.title} (#{page.slug})"

@@ not_found
#content
  %p 
    This page doesn't exist yet.
    %a(href="#{@slug}?create_new=yes") Create this page

@@ edit
#content
  %form#edit-form(action="/pages" method="post")
    %input(type="hidden" name="page[slug]" value="#{@page.slug}")
    
    %h1= "Editing #{@page.slug}"
    
    %p
      %label(for="page_title") Title:
      %input(type="text" id="page_title" name="page[title]" value="#{@page.title}")
    
    %p
      %label(for="page_body") Body:
      %textarea(id="page_body" name="page[body]")~ @page.body
    
    %p
      %label(for="page_editor_name") Your name:
      %input(type="text" id="page_editor_name" name="page[editor_name]")
    
    %p
      %button(type="submit") Create new version
  
  %hr
  
  %form#delete-form(action="/pages/#{@page.id}" method="post")
    %input(type="hidden" name="_method" value="delete")
    
    %p
      %button(type="submit") Delete this version