group 'opsworks'

template '/etc/ssh/sshd_config' do
  backup false
  source 'sshd_config.erb'
  owner 'root'
  group 'root'
  mode 0440
end

sftp_base_dir = "/var/sftp/sites"

execute "create sftp base dir #{sftp_base_dir}" do
  command "sudo mkdir -p #{sftp_base_dir}"
  action :run
end

node[:sftp_sites].each do |sftp_user, public_key|
  execute "add user #{sftp_user}" do
    command "sudo adduser #{sftp_user}"
    action :run
  end
  execute "add .ssh dir for user #{sftp_user}" do
    command "sudo su - #{sftp_user} -c \"mkdir .ssh\""
    action :run
  end
  execute "chmod .ssh dir for user #{sftp_user}" do
    command "sudo su - #{sftp_user} -c \"chmod 700 .ssh\""
    action :run
  end
  execute "add publick key for user #{sftp_user}" do
    command "sudo su - #{sftp_user} -c \"echo \"#{public_key}\" > .ssh/authorized_keys\""
    action :run
  end
  execute "chmod .ssh dir for user #{sftp_user}" do
    command "sudo su - #{sftp_user} -c \"chmod 600 .ssh/authorized_keys\""
    action :run
  end
  base_repo = File.join(sftp_base_dir, sftp_user.to_s)
  execute "create sftp repo #{base_repo}" do
    command "sudo mkdir #{base_repo}"
    action :run
  end
  [:download, :upload].each do |sftp_folder|
    dir = File.join(base_repo, sftp_folder.to_s)
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

