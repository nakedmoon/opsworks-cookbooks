include_recipe 'deploy'
Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  
  execute "updating crontab" do
    user deploy[:user]
    cwd "#{deploy[:deploy_to]}/current"
    command "bundle exec whenever -w -s environment=#{deploy[:env]}"
    action :run
  end

  template "#{deploy[:deploy_to]}/shared/config/settings.yml" do
    source 'videl/settings.yml.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
      :videl_settings => node[:settings],
      :videl_env => deploy[:env]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end
end
