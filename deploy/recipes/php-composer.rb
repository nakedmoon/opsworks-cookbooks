#
# Cookbook Name:: deploy
# Recipe:: php-composer
#

include_recipe "deploy"

node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping deploy::php application #{application} as it is not an PHP app")
    next
  end

  execute "install composer" do
    cwd deploy[:current_path]
    command "curl -s https://getcomposer.org/installer | php"
    action :run
    only_if {
      File.exists?(deploy[:current_path]) &&
          ::File.exists?("#{deploy[:current_path]}/composer.json") &&
          !::File.exists?("#{deploy[:current_path]}/composer.phar")
    }
  end

  execute "install composer packages" do
    cwd deploy[:current_path]
    command "php composer.phar install --no-dev --no-interaction --optimize-autoloader"
    action :run
    user deploy[:user]
    only_if {
      File.exists?(deploy[:current_path]) &&
          ::File.exists?("#{deploy[:current_path]}/composer.json") &&
          ::File.exists?("#{deploy[:current_path]}/composer.phar")
    }
  end

end