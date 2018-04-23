group 'opsworks'
chef_gem 'ruby-shadow'

template '/etc/ssh/sshd_config' do
  backup false
  source 'sshd_config.erb'
  owner 'root'
  group 'root'
  variables :sftp_sites => node[:sftp_sites], :sftp_root => node[:sftp_root]
  mode 0440
end

sftp_base_dir = node[:sftp_root]

execute "create sftp base dir #{sftp_base_dir}" do
  command "sudo mkdir -p #{sftp_base_dir}"
  action :run
end

node[:sftp_sites].each do |sftp_site|
  user "add user #{sftp_site[:user]}" do
    username sftp_site[:user]
    password sftp_site[:password] if sftp_site[:password].present?
  end

  execute "add .ssh dir for user #{sftp_site[:user]}" do
    command "sudo su - #{sftp_site[:user]} -c \"mkdir -p .ssh\""
    action :run
  end

  execute "chmod .ssh dir for user #{sftp_site[:user]}" do
    command "sudo su - #{sftp_site[:user]} -c \"chmod 700 .ssh\""
    action :run
  end

  template "/home/#{sftp_site[:user]}/.ssh/authorized_keys" do
    backup false
    source 'authorized_keys.erb'
    owner sftp_site[:user]
    group sftp_site[:user]
    variables :public_key => sftp_site[:public_key] || ""
    mode 0600
  end

  base_repo = File.join(sftp_base_dir, sftp_site[:user])
  execute "create sftp repo #{base_repo}" do
    command "sudo mkdir -p #{base_repo}"
    action :run
  end


  # SFTP Folder
  sftp_dir = File.join(base_repo, sftp_site[:folder])
  execute "create sftp repo #{sftp_dir}" do
    command "sudo mkdir -p #{sftp_dir}"
    action :run
  end

  execute "chown #{sftp_dir}" do
    command "sudo chown #{sftp_site[:user]}:#{sftp_site[:user]} #{sftp_dir}"
    action :run
  end

  execute "chmod #{sftp_dir}" do
    command "sudo chmod #{node[:sftp_permission]} -R #{sftp_dir}"
    action :run
  end
end

service "sshd" do
  action :restart
end

