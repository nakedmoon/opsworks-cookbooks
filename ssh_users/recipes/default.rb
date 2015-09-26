group 'opsworks'

existing_ssh_users = load_existing_ssh_users
existing_ssh_users.each do |id, name|
  unless node[:ssh_users][id]
    teardown_user(name)
  end
end

node[:ssh_users].each_key do |id|
  if existing_ssh_users.has_key?(id)
    unless existing_ssh_users[id] == node[:ssh_users][id][:name]
      rename_user(existing_ssh_users[id], node[:ssh_users][id][:name])
    end
  else
    node.set[:ssh_users][id][:uid] = id
    setup_user(node[:ssh_users][id])
  end
  set_public_key(node[:ssh_users][id])
end

system_sudoer = case node[:platform]
                when 'debian'
                  'admin'
                when 'ubuntu'
                  'ubuntu'
                when 'redhat','centos','fedora','amazon'
                   'ec2-user'
                end

template '/etc/sudoers' do
  backup false
  source 'sudoers.erb'
  owner 'root'
  group 'root'
  mode 0440
  variables :sudoers => node[:sudoers], :system_sudoer => system_sudoer
  only_if { infrastructure_class? 'ec2' }
end

template '/etc/sudoers.d/opsworks' do
  backup false
  source 'sudoers.d.erb'
  owner 'root'
  group 'root'
  mode 0440
  variables :sudoers => node[:sudoers], :system_sudoer => system_sudoer
  not_if { infrastructure_class? 'ec2' }
end

template '/etc/ssh/sshd_config' do
  backup false
  source 'sshd_config.erb'
  owner 'root'
  group 'root'
  mode 0440
end

execute "create sftp repo /var/sftp/sites/genworth" do
  command "sudo mkdir -p /var/sftp/sites/genworth"
  action :run
end


[:genworth].each do |sftp_user|
  [:download, :upload].each do |sftp_folder|
    dir = "/var/sftp/sites/#{sftp_user}/#{sftp_folder}"
    execute "create sftp repo download #{dir}" do
      command "sudo mkdir #{dir}"
      action :run
    end
    execute "chown #{dir}" do
      command "sudo chown root:#{sftp_user} #{dir}"
      action :run
    end
    execute "chmod #{dir}" do
      command "sudo chmod 775 #{dir}"
      action :run
    end

  end
end

