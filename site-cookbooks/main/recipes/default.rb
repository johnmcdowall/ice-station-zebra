# chef/site-cookbooks/main/recipes/default.rb

# setup

rbenv_ruby node['ruby-version']
rbenv_global node['ruby-version']

############ GEMS ###################
rbenv_gem 'bundler'
rbenv_gem 'bluepill'
rbenv_gem 'unicorn'

user node[:user][:name] do
  password node[:user][:password]
  gid 'sudo'
  home "/home/#{node[:user][:name]}"
  shell '/bin/bash'
  supports :manage_home => true
end

directory "#{node[:deploy_to]}/tmp/sockets" do
  owner node[:user][:name]
  group 'sudo'
  recursive true
end

# certificates

directory "#{node[:deploy_to]}/certificate" do
  owner node[:user][:name]
  recursive true
end

cookbook_file "#{node[:deploy_to]}/certificate/#{node[:environment]}.crt" do
  source "#{node[:environment]}.crt"
  action :create_if_missing
end

cookbook_file "#{node[:deploy_to]}/certificate/#{node[:environment]}.key" do
  source "#{node[:environment]}.key"
  action :create_if_missing
end

######## POSTGRES #############

include_recipe 'build-essential'

package "postgresql-contrib-9.1"

package "postgresql-server-dev-9.1"

include_recipe "postgresql::server"

include_recipe "database::postgresql"

postgresql_connection_info = {:host => "127.0.0.1",
                              :port => node['postgresql']['config']['port'],
                              :username => 'postgres',
                              :password => node['postgresql']['password']['postgres']}

postgresql_database 'exocortex_prod' do
  connection postgresql_connection_info
  action :create
end

postgresql_database_user "deployer" do
  connection postgresql_connection_info
  password node['postgresql']['password']['deployer']
  template 'template0'
  encoding "utf8"
  action :create
end

postgresql_database_user "deployer" do
  connection postgresql_connection_info
  database_name 'exocortex_prod'
  privileges [:all]
  action :grant
end


# configuration

template '/etc/nginx/sites-enabled/default' do
  source 'nginx.erb'
  owner 'root'
  group 'root'
  mode 0644
  notifies :restart, 'service[nginx]'
end

service 'nginx'