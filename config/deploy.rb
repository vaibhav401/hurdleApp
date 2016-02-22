
require 'rvm/capistrano'
require 'bundler/capistrano'
 
#RVM and bundler settings

set :bundler_cmd, "bundle install --deployment --without=development,test"
set :bundle_dir, "/home/deploy/.rvm/gems/ruby-2.0.0-p247/gems"
set :rvm_ruby_string, :local
set :rack_env, :production
      # use the same ruby as used locally for deployment
set :use_sudo, false

before 'deploy', 'rvm:install_rvm'  # install/update RVM
before 'deploy', 'rvm:install_ruby' 
#general info

set :default_shell, "/bin/bash -l"
set :user, 'deploy'
set :domain, 'www-huddle.practodev.com'
set :applicationdir, "/var/www/hurdleapp"
set :scm, 'git'
set :application, "hurdleapp"
set :repository,  "https://github.com/vaibhav401/hurdleApp.git"
set :branch, 'master'
set :git_shallow_clone, 1
set :scm_verbose, true
set :deploy_via, :remote_cache
 
role :web, domain                          # Your HTTP server, Apache/etc
role :app, domain                          # This may be the same as your `Web` server
role :db,  domain, :primary => true # This is where Rails migrations will run
#role :db,  "your slave db-server here"
#deploy config
set :deploy_to, applicationdir
set :deploy_via, :export
 
#addition settings. mostly ssh
ssh_options[:forward_agent] = true
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_rsa")]
ssh_options[:paranoid] = false
default_run_options[:pty] = true
# if you want to clean up old releases on each deploy uncomment this:
# after "deploy:restart", "deploy:cleanup"
 
# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts
 
# After an initial (cold) deploy, symlink the app and restart nginx
after "deploy:cold" do
  admin.nginx_restart
end
 
# As this isn't a rails app, we don't start and stop the app invidually
namespace :deploy do
  desc "Not starting as we're running passenger."
  task :start do
  end
end



