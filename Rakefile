namespace :db do
  desc "Migrate the DB"
  task :migrate do
    require "migration"
    migrate_up!
  end
  
  desc "Prepare the db after deploying a new app"
  task :prepare => :migrate do
    require "hickey"
    p = Page.new :slug => "/", :title => "Homepage", :body => "Welcome to your new wiki."
    p.skip_math_problem!
    p.save
  end
  
  namespace :math_problems do
    desc "Clear all math problems cached in the db"
    task :clear do
      require "hickey"
      MathProblem.all.destroy
    end
  end
end