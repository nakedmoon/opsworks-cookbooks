#
# Cookbook Name:: deploy
# Recipe:: php-migrate
#

include_recipe "deploy"

node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping deploy::php application #{application} as it is not an PHP app")
    next
  end

  log "check environment" do
    message "Hyena Environment: #{ENV['HYENA_ENV']}"
    level :info
  end

  php_env = ENV['HYENA_ENV'] || :development
  
  execute "migrate db with phinx" do
    cwd deploy[:current_path]
    command "php vendor/bin/phinx migrate -e #{php_env}"
    action :run
    
    only_if do 
      File.exists?(deploy[:current_path])
    end
  end
    
end


