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

DataMapper::Logger.new(STDOUT, :debug) # :off, :fatal, :error, :warn, :info, :debug
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///Users/#{`whoami`.strip}/Desktop/wiki.db")

class Page
  include DataMapper::Resource
  
  attr_accessor :math_problem, :math_answer
  
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
  
  validates_with_method :math_problem_acceptance
  
  def self.first_for_slug(what)
    first(:slug => what, :order => [:version.desc])
  end
  
  def self.all_for_slug(what)
    all(:slug => what, :order => [:version.asc])
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

class Hickey < Sinatra::Base
  enable :methodoverride, :static, :sessions, :logging
  set :app_file, __FILE__
  set :haml, { :format => :html5 }
  use_in_file_templates!
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
  
  def ip_parts
    @ip_parts ||= Digest::SHA1.hexdigest(request.ip + "lkjsdf8*&^kjdsI23").scan(/.{20}/)
  end
  
  def must_have_ip_parts!
    if params[ip_parts.first] != ip_parts.last
      throw :halt, [500, "Problem."]
    end
  end
  
  def generate_problems # best method name ever!
    @edit_problem = MathProblem.generate
    @delete_problem = MathProblem.generate
  end
  
  get "/pages" do
    # ATTENTION: this will only work with postgres (sorry)
    @pages = repository.adapter.select("SELECT DISTINCT ON (slug) id, slug, title, version FROM pages ORDER BY slug ASC, version DESC")
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
    generate_problems
    haml :edit
  end
  
  post "/pages" do
    must_have_ip_parts!
    
    @page = Page.new params[:page]
    @page.editor_ip = request.ip
    
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
      message "Couldn't delete the vesion.", :error
      generate_problems
      haml :edit
    end
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
  %li= "Last edited by #{h @page.editor_name}"
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
      %input(type="text" id="page_title" name="page[title]" value="#{@page.title}" maxlength="255")
    
    %p
      %label(for="page_body") Body:
      %textarea(id="page_body" name="page[body]")~ @page.body
    
    %p
      %label(for="page_editor_name") Your name:
      %input(type="text" id="page_editor_name" name="page[editor_name]" maxlength="100")
    
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