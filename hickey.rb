$: << File.dirname(__FILE__)

class Array
  def random
    self[rand(length)-1]
  end
end

require 'sinatra/base'
require 'dm-core'
require 'dm-timestamps'
require 'dm-validations'
require 'rdiscount'
require 'digest/sha1'
require 'htmldiff'
require 'active_support/core_ext/object/blank'

DataMapper::Logger.new(STDOUT, :info) # :off, :fatal, :error, :warn, :info, :debug
DataMapper.setup(:default, ENV['DATABASE_URL'] || "postgres://localhost/hickey")

class Page
  include DataMapper::Resource
  extend DataObjects::Quoting # is this a good idea?
  
  attr_accessor :math_problem, :math_answer
  @@search_indexes = [:title, :body]
  
  property :id, Serial
  property :slug, String, :length => 255, :index => true
  property :title, String, :length => 255
  property :body, Text
  property :rendered_body, Text
  property :version, Integer, :default => 0, :index => true
  property :editor_name, String, :length => 255, :default => "nobody"
  property :editor_ip, String
  property :created_at, DateTime
  
  before :save, :render_body
  before :save, :next_version
  
  validates_with_method :math_problem_acceptance
  
  def self.first_for_slug(what)
    first(:slug => what, :order => [:version.desc])
  end
  
  def self.all_for_slug(what)
    all(:slug => what, :order => [:version.desc])
  end
  
  def self.all_distinct
    # ATTENTION: this will only work with postgres (sorry)
    repository.adapter.select("SELECT DISTINCT ON (slug) id, slug, title, version, created_at FROM pages ORDER BY slug ASC, version DESC")
  end
  
  def self.search(what)
    # ATTENTION: this will only work with postgres (sorry)
    repository.adapter.select("SELECT DISTINCT ON (slug) id, slug, title, version, created_at FROM pages WHERE title_search_index @@ plainto_tsquery(#{quote_value(what)}) OR body_search_index @@ plainto_tsquery(#{quote_value(what)}) ORDER BY slug ASC, version DESC")
  end
  
  def self.recent
    # all(:created_at.gt => Time.now - (86400 * 2))
    # ATTENTION: this will only work with postgres (sorry)
    repository.adapter.select("SELECT DISTINCT ON (slug) id, slug, title, version, created_at FROM pages WHERE created_at > '#{Time.now - (86400 * 2)}' ORDER BY slug ASC, version DESC")
  end
  
  def relative_time
    distance = Time.now - created_at.to_time
    time = created_at.strftime("%I:%M %p").downcase.gsub(/^0/, "")
    hours = (distance / 60 / 60).to_i
    
    if hours > 1
      "last modified #{hours} hours ago at #{time}"
    elsif hours == 1
      "last modified 1 hour ago at #{time}"
    else
      "last modified at #{time}"
    end
  end
  
  def skip_math_problem!
    @skip_math_problem = true
  end
  
  def destroy_after_checking(math_problem_id, math_answer)
    self.math_problem = math_problem_id
    self.math_answer = math_answer
    
    if math_problem_acceptance === true
      self.destroy
    else
      false
    end
  end
  
protected
  def render_body
    self.rendered_body = RDiscount.new(body || "").to_html
  end
  
  def next_version
    if version == 0 || version.blank?
      newest_page = self.class.first_for_slug(slug)
      self.version = newest_page ? newest_page.version + 1 : 1
      self.editor_name = "nobody" if editor_name.blank?
    end
  end
  
  def math_problem_acceptance
    if @skip_math_problem || MathProblem.get(math_problem).answer == math_answer.to_i
      true
    else
      [false, "Incorrect answer given for the math problem."]
    end
  end
  
  def escape_search_string(str)
    str.gsub(/([\0\n\r\032\'\"\\])/) do
      case $1
      when "\0" then "\\0"
      when "\n" then "\\n"
      when "\r" then "\\r"
      when "\032" then "\\Z"
      when "'"  then "''"
      else "\\"+$1
      end
    end
  end
end

class MathProblem
  include DataMapper::Resource
  
  property :id, Serial
  property :first, Integer
  property :second, Integer
  property :operator, String
  
  def answer
    case operator
    when "*"
      first * second
    when "-"
      first - second
    else
      first + second
    end
  end
  
  def self.generate
    operator = %w(* - +).random
    first = rand(10) + 1
    second = rand(10) + 1
    self.first_or_create(:first => first, :second => second, :operator => operator)
  end
end

class Diff
  include DataMapper::Resource
  extend HTMLDiff
  
  property :newer_page_id, Integer, :key => true
  property :older_page_id, Integer, :key => true
  property :diff, Text
  
  # DM has a bug that tries to save these even tho they haven't changed
  # belongs_to :newer_page, :model => "Page"
  # belongs_to :older_page, :model => "Page"
  
  def self.for(older, newer)
    first_or_create(:older_page_id => older.id, :newer_page_id => newer.id)
  end
  
  def newer_page
    Page.get(newer_page_id)
  end
  def older_page
    Page.get(older_page_id)
  end
  
  before :save, :create_diff

protected
  def create_diff
    if diff.blank?
      self.diff = self.class.diff(h(older_page.body), h(newer_page.body))
    end
  end
  
  def h(what)
    Rack::Utils.escape_html(what)
  end
end



class Hickey < Sinatra::Base
  enable :methodoverride, :static, :sessions, :logging, :inline_templates
  set :app_file, __FILE__
  set :haml, { :format => :html5 }
  # use_in_file_templates!
  alias_method :h, :escape_html
  
  def title
    "#{@page ? "#{h @page.title} - " : ""} Hickey Wiki"
  end
  
  def partial(name)
    haml name, :layout => false
  end
  
  def message(what, type = "notice")
    @message = what
    @message_type = type
  end
  
  def relative_time_for(page_struct)
    page = Page.new :created_at => page_struct.created_at
    page.relative_time
  end
  
  # to work around a bug at heroku
  def request_ip
    if addr = @env['HTTP_X_FORWARDED_FOR']
      addr.split(',').first.strip # the first shall be last
    else
      @env['REMOTE_ADDR']
    end
  end
  
  def ip_parts
    @ip_parts ||= Digest::SHA1.hexdigest(request_ip + "lkjsdf8*&^kjdsI23").scan(/.{20}/)
  end
  
  def must_have_ip_parts!
    if params[:ip_first] != ip_parts.first && params[:ip_last] != ip_parts.last
      throw :halt, [500, "Problem."]
    end
  end
  
  def generate_problems # best method name ever!
    @edit_problem = MathProblem.generate
    @delete_problem = MathProblem.generate
  end
  
  def crumbs
    @crumbs ||= lambda do
      return [] unless @page && params["splat"]
      slug_parts = @page.slug.split("/").reject { |a| a.blank? }
      DataMapper.logger.info slug_parts.inspect
      return [] if slug_parts.length < 2
    
      slug_parts.delete_at(-1) # remove the page we are on
    
      slug_parts.collect { |part|
        {
          :url => "/" + slug_parts[0..slug_parts.index(part)].join("/"),
          :name => part
        }
      }
    end.call
  end
  
  get "/pages" do
    @pages = Page.all_distinct
    @pages_list_type = "pages"
    haml :pages
  end
  
  get "/search" do
    @pages = Page.search(params[:q])
    @pages_list_type = "search"
    haml :pages
  end
  
  get "/recent" do
    @pages = Page.recent
    haml :recent
  end
  
  get "/pages/:id" do
    repository do
      @page = Page.get(params[:id])
      @pages = Page.all_for_slug(@page.slug)
    
      message "This is an older version (#{@page.version})." unless @pages.first == @page
      body haml(:page)
    end
  end
  
  get "/pages/:id/diff" do
    @page = Page.get(params[:id])
    @page_before = Page.first(:slug => @page.slug, :version => @page.version - 1)
    
    if @page_before
      @diff = Diff.for(@page_before, @page).diff
      message "Diffs show the original author's text in markdown format."
    else
      message "Version #{@page.version - 1} has been removed or never existed."
    end
    
    haml :diff
  end
  
  get "/pages/:id/edit" do
    @page = Page.get(params[:id])
    generate_problems
    haml :edit
  end
  
  post "/pages" do
    must_have_ip_parts!
    
    @page = Page.new params[:page]
    @page.editor_ip = request_ip
    
    if @page.save
      redirect @page.slug
    else
      message "There is something wrong with what you submitted.", :error
      generate_problems
      haml :edit
    end
  end
  
  delete "/pages/:id" do
    must_have_ip_parts!
    
    @page = Page.get(params[:id])
    slug = @page.slug
    
    if @page.destroy_after_checking(params[:math_problem], params[:math_answer])
      possible_past_version = Page.first_for_slug(slug)
      redirect(possible_past_version ? "#{possible_past_version.slug}" : "/")
    else
      message "Couldn't delete.", :error
      generate_problems
      haml :edit
    end
  end
  
  post "/preview" do
    @body = RDiscount.new(params[:body] || params[:page][:body] || "").to_html
    message "This is not saved yet, this is only a preview."
    haml :preview
  end
  
  get "*" do
    repository do
      @slug = params["splat"].join("/")
    
      @page = Page.first_for_slug(@slug)
    
      if @page.blank?
        if params["create_new"] == "yes"
          @page = Page.new(:slug => @slug)
          @page.skip_math_problem!
          @page.save
        else
          throw :halt, [404, haml(:not_found)]
        end
      end
    
      @pages = Page.all_for_slug(@slug)
    
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
    %meta(name="viewport" content="width=520")
  %body
    %ul#links
      %li
        %a(href="/") Homepage
      %li
        %a(href="/pages") All pages
      %li
        %a(href="/recent") Recently updated
      %li.search
        %form(action="/search" method="get")
          %input(type="search" placeholder="Search" name="q" value="#{params[:q]}")
          %button(type="submit") Search
    = partial :message
    = yield
    %script(src="/jquery.min.js")
    %script(src="/application.js")


@@ message
- unless @message.blank?
  #message(class="#{@message_type}")
    %p= @message

@@ breadcrumbs
- if crumbs.length > 0
  %ul.breadcrumbs
    %li homepage
    - crumbs.each do |crumb|
      %li
        %a(href="#{crumb[:url]}")= crumb[:name]

@@ preview
#content.preview
  ~ @body
#meta
  %p You can close this window when finished.

@@ diff
- if @diff
  #content.diff
    %pre~ @diff
#meta
  %p
    - if @page_before
      = "Showing the differences between versions #{@page.version} and #{@page_before.version}."
      %a(href="/pages/#{@page.id}")= "Back to version #{@page.version}"
    - else
      Not able to show a diff.

@@ page
#content
  ~ @page.rendered_body
= partial :breadcrumbs
%ul#meta
  %li
    %a(href="/pages/#{@page.id}/edit") Edit this page
  %li= "Last edited by #{h @page.editor_name}"
  %li.version
    %select#versions
      - @pages.each do |page|
        %option{ :value => "/pages/#{page.id}", :selected => (@page == page ? "selected" : nil) }= "Version #{page.version}"
  - if @page.version > 1
    %li.diff
      %a(href="/pages/#{@page.id}/diff")= "Show differences from version #{@page.version - 1}"

@@ pages
#content
  %ul(id="#{@pages_list_type}")
    - @pages.each do |page|
      %li(id="page-#{page.id}")
        %a(href="#{page.slug}")= "#{page.title} (#{page.slug})"
#meta
  %p All pages link to the newest version.

@@ recent
#content
  %ul#recent
    - @pages.each do |page|
      %li(id="page-#{page.id}")
        %a(href="#{page.slug}")= "#{page.title} (#{page.slug})"
        %em.created-at= relative_time_for(page)
#meta
  %p Listing all pages updated in the last 48 hours.


@@ not_found
#content
  %p 
    This page doesn't exist yet.    
%ul#meta
  %li
    %a(href="#{@slug}?create_new=yes" rel="nofollow") Create this page


@@ edit
%noscript
  #message You cannot edit pages without Javascript turned on :(
#content
  %script= "var ip_parts = ['#{ip_parts.first}', '#{ip_parts.last}'];"
  
  %form#edit-form(action="/pages" method="post")
    %input(type="hidden" name="page[slug]" value="#{@page.slug}")
    
    %h1= "Editing #{@page.slug}"
    
    %p
      %label(for="page_title") Title:
      %input(type="text" id="page_title" name="page[title]" value="#{@page.title}" maxlength="255" autofocus)
    
    %p
      %label(for="page_body") Body:
      %textarea(id="page_body" name="page[body]")~ @page.body
    
    %p
      %label(for="page_editor_name") Your name:
      %input(type="text" id="page_editor_name" name="page[editor_name]" maxlength="100" value="#{request.cookies["saved_editor_name"]}")
    
    %p.human-test
      %label(for="page_math_answer")= "What is #{@edit_problem.first} #{@edit_problem.operator} #{@edit_problem.second}?"
      %input(type="hidden" name="page[math_problem]" value="#{@edit_problem.id}")
      %input(type="text" id="page_math_answer" name="page[math_answer]" maxlength="20")
    
    %p
      %button(type="submit") Create new version
  
  %hr.delete
  
  %form#delete-form(action="/pages/#{@page.id}" method="post")
    %input(type="hidden" name="_method" value="delete")
    
    %p.human-test
      %label(for="math_answer")= "What is #{@delete_problem.first} #{@delete_problem.operator} #{@delete_problem.second}?"
      %input(type="hidden" name="math_problem" value="#{@delete_problem.id}")
      %input(type="text" id="math_answer" name="math_answer" maxlength="20")
    
    %p.button
      %button(type="submit") Delete this version
      %span This could be a bad idea, think about it.
