define :opsworks_deploy do
  application = params[:app]
  deploy = params[:deploy_data]

  directory "#{deploy[:deploy_to]}" do
    group deploy[:group]
    owner deploy[:user]
    mode "0775"
    action :create
    recursive true
  end

  if deploy[:scm]
    ensure_scm_package_installed(deploy[:scm][:scm_type])

    prepare_git_checkouts(
        :user => deploy[:user],
        :group => deploy[:group],
        :home => deploy[:home],
        :ssh_key => deploy[:scm][:ssh_key]
    ) if deploy[:scm][:scm_type].to_s == 'git'

    prepare_svn_checkouts(
        :user => deploy[:user],
        :group => deploy[:group],
        :home => deploy[:home],
        :deploy => deploy,
        :application => application
    ) if deploy[:scm][:scm_type].to_s == 'svn'

    if deploy[:scm][:scm_type].to_s == 'archive'
      repository = prepare_archive_checkouts(deploy[:scm])
      node.set[:deploy][application][:scm] = {
          :scm_type => 'git',
          :repository => repository
      }
    elsif deploy[:scm][:scm_type].to_s == 's3'
      repository = prepare_s3_checkouts(deploy[:scm])
      node.set[:deploy][application][:scm] = {
          :scm_type => 'git',
          :repository => repository
      }
    end
  end

  deploy = node[:deploy][application]

  directory "#{deploy[:deploy_to]}/shared/cached-copy" do
    recursive true
    action :delete
    only_if do
      deploy[:delete_cached_copy]
    end
  end

  directory "#{deploy[:deploy_to]}/shared/export" do
    recursive true
    action :create
    only_if do
      !File.exists?("#{deploy[:deploy_to]}/shared/export")
    end
  end

  directory "#{deploy[:deploy_to]}/shared/cache" do
    recursive true
    action :create
    only_if do
      !File.exists?("#{deploy[:deploy_to]}/shared/cache")
    end
  end


  ruby_block "change HOME to #{deploy[:home]} for source checkout" do
    block do
      ENV['HOME'] = "#{deploy[:home]}"
    end
  end

  # setup deployment & checkout
  if deploy[:scm] && deploy[:scm][:scm_type] != 'other'
    Chef::Log.debug("Checking out source code of application #{application} with type #{deploy[:application_type]}")
    deploy deploy[:deploy_to] do
      provider Chef::Provider::Deploy.const_get(deploy[:chef_provider])
      keep_releases deploy[:keep_releases]
      repository deploy[:scm][:repository]
      user deploy[:user]
      group deploy[:group]
      revision deploy[:scm][:revision]
      migrate deploy[:migrate]
      migration_command deploy[:migrate_command]
      environment deploy[:environment].to_hash
      purge_before_symlink(deploy[:purge_before_symlink]) unless deploy[:purge_before_symlink].nil?
      create_dirs_before_symlink(deploy[:create_dirs_before_symlink])
      symlink_before_migrate(deploy[:symlink_before_migrate])
      symlinks(deploy[:symlinks]) unless deploy[:symlinks].nil?
      action deploy[:action]

      if deploy[:application_type] == 'rails' && node[:opsworks][:instance][:layers].include?('rails-app')
        restart_command "sleep #{deploy[:sleep_before_restart]} && #{node[:opsworks][:rails_stack][:restart_command]}"
      end

      case deploy[:scm][:scm_type].to_s
        when 'git'
          scm_provider :git
          enable_submodules deploy[:enable_submodules]
          shallow_clone deploy[:shallow_clone]
        when 'svn'
          scm_provider :subversion
          svn_username deploy[:scm][:user]
          svn_password deploy[:scm][:password]
          svn_arguments "--no-auth-cache --non-interactive --trust-server-cert"
          svn_info_args "--no-auth-cache --non-interactive --trust-server-cert"
        else
          raise "unsupported SCM type #{deploy[:scm][:scm_type].inspect}"
      end

      before_migrate do
        link_tempfiles_to_current_release

        if deploy[:application_type] == 'rails'
          if deploy[:auto_bundle_on_deploy]
            OpsWorks::RailsConfiguration.bundle(application, node[:deploy][application], release_path)
          end

          node.default[:deploy][application][:database][:adapter] = OpsWorks::RailsConfiguration.determine_database_adapter(
              application,
              node[:deploy][application],
              release_path,
              :force => node[:force_database_adapter_detection],
              :consult_gemfile => node[:deploy][application][:auto_bundle_on_deploy]
          )
          template "#{node[:deploy][application][:deploy_to]}/shared/config/database.yml" do
            cookbook "rails"
            source "database.yml.erb"
            mode "0660"
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :database => node[:deploy][application][:database],
                :environment => node[:deploy][application][:rails_env]
            )

            only_if do
              deploy[:database][:host].present?
            end
          end.run_action(:create)
        elsif deploy[:application_type] == 'aws-flow-ruby'
          OpsWorks::RailsConfiguration.bundle(application, node[:deploy][application], release_path)
        elsif deploy[:application_type] == 'php'
          template "#{node[:deploy][application][:deploy_to]}/shared/config/opsworks.php" do
            cookbook 'php'
            source 'opsworks.php.erb'
            mode '0660'
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :database => node[:deploy][application][:database],
                :memcached => node[:deploy][application][:memcached],
                :layers => node[:opsworks][:layers],
                :stack_name => node[:opsworks][:stack][:name]
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/db.php" do
            cookbook 'php'
            source 'db.php.erb'
            mode '0660'
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :database => deploy[:database],
                :current_dir => node[:deploy][application][:current_path],
                :rollbar_level => node[:rollbar_level],
                :roolbar_lib => ::File.join(node[:deploy][application][:current_path],
                                            'vendor',
                                            'rollbar',
                                            'rollbar',
                                            'src',
                                            'rollbar.php'
                ),
                :env => node[:hyena_env] || :development,
                :rollbar_token => node[:rollbar_token],
                :fastcache_include => ::File.join(node[:deploy][application][:current_path], 'phpfastcache.php')
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/phpfastcache.php" do
            cookbook 'php'
            source 'phpfastcache.php.erb'
            mode '0660'
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :fastcache_lib => ::File.join(node[:deploy][application][:current_path], 'vendor', 'phpfastcache', 'phpfastcache', 'phpfastcache', '3.0.0','phpfastcache.php'),
                :fastcache_storage => node[:fastcache_storage],
                :fastcache_path => ::File.join(node[:deploy][application][:deploy_to],'shared', 'cache'),
                :fastcache_disabled => node[:fastcache_storage] || 'false',
                :fastcache_memcached => node[:fastcache_memcached] || {:host  => "127.0.0.1",
                                                                       :port  =>  "11211",
                                                                       :timeout => "1"
                },
                :fastcache_redis => node[:fastcache_redis] || {:host  => "127.0.0.1",
                                                               :port  =>  "",
                                                               :password  =>  "",
                                                               :database  =>  "",
                                                               :timeout   =>  ""
                }
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/.htaccess" do
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
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/configuration.php" do
            cookbook 'php'
            source 'configuration.php.erb'
            mode '0660'
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :database => deploy[:database],
                :log_dir => ::File.join(node[:deploy][application][:current_path], 'log'),
                :tmp_dir => ::File.join(node[:deploy][application][:current_path], 'tmp')
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/phinx.yml" do
            cookbook 'php'
            source 'phinx.yml.erb'
            mode '0660'
            owner node[:deploy][application][:user]
            group node[:deploy][application][:group]
            variables(
                :database => deploy[:database],
                :migrations_dir => ::File.join(node[:deploy][application][:deploy_to], 'migrations'),
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/fit2u_srv_config.inc.php" do
            cookbook 'php'
            source 'fit2u_srv_config.inc.php.erb'
            mode '0660'
            owner deploy[:user]
            group deploy[:group]
            variables(
                :export_path => "#{deploy[:deploy_to]}/shared/export",
                :log_dir => ::File.join(node[:deploy][application][:current_path], 'log')
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
          template "#{node[:deploy][application][:deploy_to]}/shared/config/fit2u_appl_config.inc.php" do
            cookbook 'php'
            source 'fit2u_appl_config.inc.php.erb'
            mode '0660'
            owner deploy[:user]
            group deploy[:group]
            variables(
                :service_base_url => node[:service_url]
            )
            only_if do
              File.exists?("#{node[:deploy][application][:deploy_to]}/shared/config")
            end
          end
        elsif deploy[:application_type] == 'nodejs'
          if deploy[:auto_npm_install_on_deploy]
            OpsWorks::NodejsConfiguration.npm_install(application, node[:deploy][application], release_path, node[:opsworks_nodejs][:npm_install_options])
          end
        end

        # run user provided callback file
        run_callback_from_file("#{release_path}/deploy/before_migrate.rb")
      end
    end
  end

  ruby_block "change HOME back to /root after source checkout" do
    block do
      ENV['HOME'] = "/root"
    end
  end

  if deploy[:application_type] == 'rails' && node[:opsworks][:instance][:layers].include?('rails-app')
    case node[:opsworks][:rails_stack][:name]

      when 'apache_passenger'
        passenger_web_app do
          application application
          deploy deploy
        end

      when 'nginx_unicorn'
        unicorn_web_app do
          application application
          deploy deploy
        end

      else
        raise "Unsupport Rails stack"
    end
  end

  bash "Enable selinux var_log_t target for application log files" do
    dir_path_log = "#{deploy[:deploy_to]}/shared/log"
    context = "var_log_t"

    user "root"
    code <<-EOH
    semanage fcontext --add --type #{context} "#{dir_path_log}(/.*)?" && restorecon -rv "#{dir_path_log}"
    EOH
    not_if { OpsWorks::ShellOut.shellout("/usr/sbin/semanage fcontext -l") =~ /^#{Regexp.escape("#{dir_path_log}(/.*)?")}\s.*\ssystem_u:object_r:#{context}:s0/ }
    only_if { platform_family?("rhel") && ::File.exist?("/usr/sbin/getenforce") && OpsWorks::ShellOut.shellout("/usr/sbin/getenforce").strip == "Enforcing" }
  end

  template "/etc/logrotate.d/opsworks_app_#{application}" do
    backup false
    source "logrotate.erb"
    cookbook 'deploy'
    owner "root"
    group "root"
    mode 0644
    variables( :log_dirs => ["#{deploy[:deploy_to]}/shared/log" ] )
  end
end
