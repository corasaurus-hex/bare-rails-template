# create fresh git repo
git :init
git :add    => '.'
git :commit => '-a -m "fresh rails app"'

# include gems
gem 'rspec', :group => [:test, :development]
gem 'rspec-rails', :group => [:test, :development]
run 'bundle install'

run 'capify .'
remove_file 'config/deploy.rb'
file 'config/deploy.rb', '#-------------------------------------
# SETTINGS
#-------------------------------------

set :application,   "CHANGEME"
set :repository,    "CHANGEME"
set :deploy_via,    :remote_cache
set :scm,           :git
set :user,          "deploy"
set :use_sudo,      false
set :keep_releases, 5

server "CHANGEME", :web, :app, :db, :primary => true


#-------------------------------------
# ENVIRONMENT(S)
#-------------------------------------

set :deploy_to, "/data/#{application}"
set :branch,    "production"
set :rails_env, "production"


#-------------------------------------
# DEPLOY
#-------------------------------------

after "deploy:symlink", "deploy:cleanup"
namespace :deploy do
  task :start do
    run "sudo /etc/init.d/god start"
  end

  task :stop do
    run <<-CMD
      sudo god stop resque &&
      sudo /etc/init.d/god stop
    CMD
  end

  desc "Restart passenger by touching restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run <<-CMD
      touch #{current_path}/tmp/restart.txt &&
      sudo god restart resque
    CMD
  end

  after "deploy:update_code", "deploy:symlink_configs"
  task :symlink_configs, :roles => :app, :except => { :no_release => true, :no_symlink => true } do
    run <<-CMD
      cd #{release_path} &&
      ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml &&
      ln -nfs #{shared_path}/config/application.yml #{release_path}/config/application.yml
    CMD
  end

  after "deploy:setup", "deploy:create_shared_directories"
  task :create_shared_directories do
    run "mkdir -p #{shared_path}/config #{shared_path}/bundle"
  end

  before "deploy:migrate", "deploy:create_db_if_missing"
  task :create_db_if_missing, :roles => :db, :except => { :no_release => true } do
    run "cd #{release_path} && env RAILS_ENV=#{rails_env} rake db:create || echo"
  end

  after "deploy:symlink_bundle", "deploy:bundle"
  task :bundle do
    run "cd #{release_path} && bundle install --deployment"
  end

  after "deploy:symlink_configs", "deploy:symlink_bundle"
  task :symlink_bundle, :except => { :no_release => true, :no_symlink => true } do
    run "cd #{release_path} && ln -nfs #{shared_path}/bundle #{release_path}/vendor/bundle"
  end

  before "deploy:cold", "deploy:remove_current"
  task :remove_current do
    run "[ -d #{deploy_to}/current ] && sudo rm -rf #{deploy_to}/current"
  end
end
'
remove_file ".gitignore"
file ".gitignore", <<-END
/log/*.log
/tmp/**/*
/config/*.yml
/.rvmrc
.DS_Store
/.bundle
/config/deploy.rb
END


# run rspec generators
generate 'rspec:install'

# create rspec.rb in the config/initializers directory to use rspec as the default test framework
initializer 'rspec.rb', <<-EOF
  Rails.application.config.generators.test_framework :rspec
EOF

# download latest unobtrusive rails adapter for jquery 
get 'http://github.com/rails/jquery-ujs/raw/master/src/rails.js', 'public/javascripts/rails.js'

# create jquery.rb in the config/initializers directory to use jquery as the default javascript framework
initializer 'jquery.rb', <<-EOF
  Rails.application.config.action_view.javascript_expansions[:defaults] = %w(http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js rails)
EOF

# commit template results to repo
git :add => "."
git :commit => '-a -m "applied application template"'
