node[:deploy].each do |application, deploy|
  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping php::configure application #{application} as it is not an PHP app")
    next
  end

  template "#{deploy[:deploy_to]}/shared/config/base.config.php" do
    cookbook 'php'
    source 'base.config.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :shared_path => File.join(deploy[:deploy_to], "shared"),
        :service_url => node[:service_url]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  template "#{deploy[:deploy_to]}/shared/config/rollbar.php" do
    cookbook 'php'
    source 'rollbar.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :current_dir => node[:deploy][application][:current_path],
        :roolbar_lib => ::File.join(deploy[:deploy_to], 'current','vendor','rollbar','rollbar','src','rollbar.php'),
        :rollbar => node[:rollbar]
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  template "#{deploy[:deploy_to]}/shared/config/slack.php" do
    cookbook 'php'
    source 'slack.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :slack => node[:slack],
        :vendor_autoload => ::File.join(deploy[:deploy_to], 'current', 'vendor', 'autoload.php')
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  template "#{deploy[:deploy_to]}/shared/config/zurich.config.php" do
    cookbook 'php'
    source 'zurich.config.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :sftp => node[:sftp_sites][:zurich],
        :private_key_file => node[:sftp_sites][:zurich][:private_key].present? ? "/home/#{deploy[:user]}/.ssh/zurich.pem" : nil
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  node[:sftp_sites].each do |name, sftp|
    next unless sftp[:private_key].present?
    template "/home/#{deploy[:user]}/.ssh/#{name}.pem" do
      cookbook 'php'
      source 'sftp.pem.erb'
      mode '0600'
      owner deploy[:user]
      group deploy[:group]
      variables :private_key => sftp[:private_key]
    end
  end


  if node[:cron_scripts].present?

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
      crontab_cli = sprintf("%s %s %s %s %s cd %s && php %s", *time.values, cli_path, cmd)
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








end
