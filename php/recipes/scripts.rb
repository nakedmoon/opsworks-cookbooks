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

  template "#{deploy[:deploy_to]}/shared/config/zurich.config.php" do
    cookbook 'php'
    source 'zurich.config.php.erb'
    mode '0660'
    owner deploy[:user]
    group deploy[:group]
    variables(
        :sftp => node[:sftp_sites][:zurich],
        :private_key_file => "/home/#{deploy[:user]}/.ssh/zurich.pem"
    )
    only_if do
      File.exists?("#{deploy[:deploy_to]}/shared/config")
    end
  end

  node[:sftp_sites].each do |name, sftp|
    template "/home/#{deploy[:user]}/.ssh/#{name}.pem" do
      cookbook 'php'
      source 'sftp.pem.erb'
      mode '0600'
      owner deploy[:user]
      group deploy[:group]
      variables :private_key => sftp[:private_key]
    end
  end




end
