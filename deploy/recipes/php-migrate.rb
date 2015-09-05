#
# Cookbook Name:: deploy
# Recipe:: rails-restart
#

include_recipe "deploy"

node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping deploy::php application #{application} as it is not an PHP app")
    next
  end
  
  execute "migrate db with phinx" do
    cwd deploy[:current_path]
    php_env = ENV['HYENA_ENV'] || :development
    command "php vendor/bin/phinx migrate -e #{php_env}"
    action :run
    
    only_if do 
      File.exists?(deploy[:current_path])
    end
  end
    
end


