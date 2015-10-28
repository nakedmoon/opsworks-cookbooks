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

  directory "#{deploy[:deploy_to]}/shared/cache" do
    recursive true
    action :delete
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/cache")
    end
  end


  directory "#{deploy[:deploy_to]}/shared/cache" do
    recursive true
    action :create
    owner deploy[:group]
    group deploy[:group]
  end

  execute "chage ownership of cache folder" do
    command "sudo chown #{deploy[:group]}:#{deploy[:group]} -R #{deploy[:deploy_to]}/shared/cache"
  end

  [:export, :cache].each do |sym_dir|
    sym_dir_path = ::File.join(node[:deploy][application][:current_path],sym_dir.to_s)
    sym_dir_dest = ::File.join(node[:deploy][application][:deploy_to], 'shared', sym_dir.to_s)
    directory sym_dir_path do
      action :delete
      recursive true
      Chef::Log.debug("Remove dir #{sym_dir_path} before linking")
      only_if do
        File.exists?(sym_dir_path) && File.directory?(sym_dir_path)
      end
    end
    link sym_dir_path do
      to sym_dir_dest
      action :create
      link_type :symbolic
    end
  end

  node[:htaccess_deny].each do |dir|
    link_name = ::File.join(node[:deploy][application][:current_path], dir, '.htaccess')
    link_dest = ::File.join(node[:deploy][application][:deploy_to], 'shared', 'config', '.htaccess_deny')
    link link_name do
      to link_dest
      action :create
      link_type :symbolic
      Chef::Log.debug("Linking #{link_name} to #{link_dest}")
    end
  end


end

