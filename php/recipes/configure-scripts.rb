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

  template "#{deploy[:deploy_to]}/configuration/base.config.php" do
    cookbook 'php'
    source 'base.config.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :current_dir => deploy[:deploy_to]
    )
  end


  template "#{deploy[:deploy_to]}/openssl.cnf" do
    cookbook 'php'
    source 'openssl.cnf.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :current_dir => deploy[:deploy_to]
    )
  end

end
