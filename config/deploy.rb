
require 'rvm/capistrano'
require 'bundler/capistrano'
 
#RVM and bundler settings
set :default_environment, {
  'PATH' => "/home/ubuntu/.rvm/gems/ruby-2.2.1/bin:/home/ubuntu/.rvm/gems/ruby-2.2.1@global/bin:/home/ubuntu/.rvm/rubies/ruby-2.2.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/home/ubuntu/.rvm/bin:/home/ubuntu/.rvm/bin"
}

set :bundler_cmd, "bundle install --deployment --without=development,test"
set :bundle_dir, "/home/ubuntu/.rvm/gems/ruby-2.2.1/bin/bundler"
set :rvm_ruby_string, :local
set :rack_env, :production
      # use the same ruby as used locally for deployment
set :use_sudo, false

# before 'deploy', 'rvm:install_rvm'  # install/update RVM
# before 'deploy', 'rvm:install_ruby' 
#general info

set :default_shell, "/bin/bash -l"

set :user, 'ubuntu'
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
# set :deploy_to, applicationdir
# set :deploy_via, :export
 

set :rack_env, :production

set :deploy_to, "/var/www/huddleapp"
set :unicorn_conf, "#{current_path}/config/unicorn.rb"
set :unicorn_pid, "#{shared_path}/pids/unicorn.pid"



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
	
  task :restart do
    run "if [ -f #{unicorn_pid} ]; then kill -USR2 `cat #{unicorn_pid}`; else cd #{current_path} && bundle exec unicorn -c #{unicorn_conf} -E #{rack_env} -D; fi"
  end

  task :start do
    run "cd #{current_path} && bundle exec unicorn -c #{unicorn_conf} -E #{rack_env} -D"
  end

  task :stop do
    run "if [ -f #{unicorn_pid} ]; then kill -QUIT `cat #{unicorn_pid}`; fi"
  end
end



