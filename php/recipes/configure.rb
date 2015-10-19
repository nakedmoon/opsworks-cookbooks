Chef::Log.level = :debug

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
        :current_dir => deploy[:deploy_to],
        :rollbar_level => node[:rollbar_level],
        :roolbar_lib => ::File.join(deploy[:deploy_to], 'current', 'vendor', 'rollbar', 'rollbar', 'src', 'rollbar.php'),
        :env => node[:hyena_env] || :development,
        :rollbar_token => node[:rollbar_token],
        :rollbar_branch => deploy[:scm][:revision]
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
        :log_dir => ::File.join(deploy[:deploy_to], 'log'),
        :tmp_dir => ::File.join(deploy[:deploy_to], 'tmp')
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
        :database => deploy[:database],
        :migrations_dir => ::File.join(deploy[:deploy_to], 'migrations'),
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  # write out .htaccess
  template "#{deploy[:deploy_to]}/shared/config/.htaccess" do
    cookbook 'php'
    source '.htaccess.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :error_level => node[:php_error_level],
        :time_zone => node[:php_timezone]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  # write out fit2u_srv_config.inc.php
  template "#{deploy[:deploy_to]}/shared/config/fit2u_srv_config.inc.php" do
    cookbook 'php'
    source 'fit2u_srv_config.inc.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :export_path => "#{deploy[:deploy_to]}/shared/export",
        :log_dir => ::File.join(deploy[:deploy_to], 'log')
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end


  # write out fit2u_appl_config.inc.php
  template "#{deploy[:deploy_to]}/shared/config/fit2u_appl_config.inc.php" do
    cookbook 'php'
    source 'fit2u_appl_config.inc.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :service_base_url => node[:service_url]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  # write out crontab
  template "#{deploy[:deploy_to]}/shared/config/#{deploy[:user]}_crontab" do
    cookbook 'php'
    source 'crontab.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  crontab_file = "#{deploy[:deploy_to]}/shared/config/#{deploy[:user]}_crontab"

  node[:cron_scripts].each do |cmd, time|
    cli_path = File.join(deploy[:deploy_to], "current")
    crontab_cli = sprintf("%s %s %s %s %s cd %s && php %s", *time.values, cli_path, File.join(cli_path, cmd))
    execute "add crontab line for #{cmd}" do
      user deploy[:user]
      command "echo '#{crontab_cli}' >> #{crontab_file}"
      action :run
    end
  end

  if node[:opsworks][:layers]['php-app'][:instances].keys.size <= 1
    execute "add crontab for user #{deploy[:user]}" do
      user deploy[:user]
      command "crontab #{crontab_file}"
      action :run
    end
  end












end
