include_recipe 'deploy'
Chef::Log.level = :debug

node[:deploy].each do |application, deploy|

  remote_counter_env = deploy[:env]
  current_path = deploy[:current_path]
  unicorn_pid_dir = File.join(deploy[:deploy_to], 'shared', 'pids')
  unicorn_pid_path = File.join(unicorn_pid_dir,'unicorn.pid')
  unicorn_config_dir = File.join(deploy[:deploy_to], 'shared', 'config')
  unicorn_sockets_dir = File.join(deploy[:deploy_to], 'shared', 'sockets')
  unicorn_log_dir = File.join(deploy[:deploy_to], 'shared', 'log')
  unicorn_config_path = File.join(unicorn_config_dir, 'shared', 'config', 'unicorn.rb')


  directory unicorn_pid_dir do
    mode '0770'
    owner deploy[:user]
    group deploy[:group]
    action :create
    recursive true
  end

  directory unicorn_config_dir do
    mode '0770'
    owner deploy[:user]
    group deploy[:group]
    action :create
    recursive true
  end

  directory unicorn_sockets_dir do
    mode '0770'
    owner deploy[:user]
    group deploy[:group]
    action :create
    recursive true
  end

  directory unicorn_log_dir do
    mode '0770'
    owner deploy[:user]
    group deploy[:group]
    action :create
    recursive true
  end

  template File.join(unicorn_config_dir, 'settings.yml') do
    source 'remote_counter/settings.yml.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :remote_counter_settings => node[:remote_counter_settings],
        :remote_counter_env => remote_counter_env
    )
    only_if do
      File.exists?(unicorn_config_dir)
    end
  end

  template File.join(unicorn_config_dir, 'unicorn.conf') do
    source 'remote_counter/unicorn.conf.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :remote_counter_settings => node[:remote_counter_settings],
        :working_dir => current_path,
        :stderr_path => File.join(unicorn_log_dir, 'unicorn.stderr.log'),
        :stdout_path => File.join(unicorn_log_dir, 'unicorn.stdout.log'),
        :sockets_path => File.join(unicorn_sockets_dir,'unicorn.sock'),
        :gemfile_path => File.join(current_path, 'Gemfile'),
        :pid_path => unicorn_pid_path
    )
    only_if do
      File.exists?(unicorn_config_dir)
    end
  end

  execute 'restart_unicorn' do
    Chef::Log.info("Restart Unicorn ...")
    cwd current_path
    user 'deploy'
    command "kill -USR2 `cat #{unicorn_pid_path}`"
    environment 'REMOTE_COUNTER_ENV' => remote_counter_env
    ignore_failure false
    only_if do
      File.exists?(unicorn_pid_path) && (pid = File.read(unicorn_pid_path).chomp) && system("ps aux | grep #{pid} | grep -v grep > /dev/null")
    end
  end

  file unicorn_pid_path do
    Chef::Log.info("Delete stale PID file....")
    action :delete
    only_if do
      File.exists?(unicorn_pid_path) && (pid = File.read(unicorn_pid_path).chomp) && !system("ps aux | grep #{pid} | grep -v grep > /dev/null")
    end
  end

  execute 'start_unicorn' do
    Chef::Log.info("Start Unicorn ....")
    cwd current_path
    user 'deploy'
    command "bundle exec unicorn --env #{remote_counter_env} -c #{unicorn_config_path} -D"
    environment 'REMOTE_COUNTER_ENV' => remote_counter_env
    ignore_failure false
    not_if do
      File.exists?(unicorn_pid_path) && (pid = File.read(unicorn_pid_path).chomp) && system("ps aux | grep #{pid} | grep -v grep > /dev/null")
    end
  end




end

