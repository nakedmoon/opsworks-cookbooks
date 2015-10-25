#
# Cookbook Name:: deploy
# Recipe:: php
#

include_recipe 'deploy'
include_recipe "mod_php5_apache2"
include_recipe "mod_php5_apache2::php"

node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping deploy::php application #{application} as it is not an PHP app")
    next
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  opsworks_deploy do
    deploy_data deploy
    app application
  end


  node[:htaccess_deny].each do |dir|
    link_name = ::File.join(node[:deploy][application][:current_path], dir, '.htaccess')
    link_dest = ::File.join(deploy[:deploy_to], 'shared', 'config', '.htaccess-deny')
    Chef::Log.debug("Linking #{link_name} to #{link_dest}")
    link link_name do
      to link_dest
      owner deploy[:user]
      group deploy[:group]
      action :create
      link_type :symbolic
    end
  end

end

