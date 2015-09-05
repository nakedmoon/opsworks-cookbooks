node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping php::configure application #{application} as it is not an PHP app")
    next
  end

  # write out opsworks.php
  template "#{deploy[:deploy_to]}/shared/config/opsworks.php" do
    cookbook 'php'
    source 'opsworks.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
      :database => deploy[:database],
      :memcached => deploy[:memcached],
      :layers => node[:opsworks][:layers],
      :stack_name => node[:opsworks][:stack][:name]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end


  # write out db.php
  template "#{deploy[:deploy_to]}/shared/config/db.php" do
    cookbook 'php'
    source 'db.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :database => deploy[:database],
        :current_dir => ::File.join(deploy[:deploy_to], 'current'),
        :env => node[:hyena_env] || :development,
        :rollbar_token => node[:rollbar_token]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  # write out configuration.php
  template "#{deploy[:deploy_to]}/shared/config/configuration.php" do
    cookbook 'php'
    source 'configuration.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :database => deploy[:database],
        :log_dir => ::File.join(deploy[:deploy_to], 'current', 'logs'),
        :tmp_dir => ::File.join(deploy[:deploy_to], 'current', 'tmp')
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end


  # write out phinx.yml
  template "#{deploy[:deploy_to]}/shared/config/phinx.yml" do
    cookbook 'php'
    source 'phinx.yml.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :database => deploy[:database]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end


end
