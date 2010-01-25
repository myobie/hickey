namespace :db do
  desc "Migrate the DB"
  task :migrate do
    require "migration"
    migrate_up!
  end
  
  desc "Prepare the db after deploying a new app"
  task :prepare do
    invoke("db:migrate")
    require "hickey"
    p = Page.new :slug => "/", :title => "Homepage", :body => "Welcome to your new wiki."
    p.skip_math_problem!
    p.save
  end
end