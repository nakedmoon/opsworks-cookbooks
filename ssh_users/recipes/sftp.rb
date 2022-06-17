group 'opsworks'

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

user_group = 'sftpers'
execute "create group if not exists" do
  command "getent group #{user_group} || groupadd #{user_group}"
  action :run
end

node[:sftp_sites].each do |sftp_site|

  execute "add user #{sftp_site[:download][:user]}" do
    command "sudo adduser #{sftp_site[:download][:user]} -g #{user_group}"
    action :run
  end

  execute "add .ssh dir for user #{sftp_site[:download][:user]}" do
    command "sudo su - #{sftp_site[:download][:user]} -c \"mkdir .ssh\""
    action :run
  end





  execute "chmod .ssh dir for user #{sftp_site[:download][:user]}" do
    command "sudo su - #{sftp_site[:download][:user]} -c \"chmod 700 .ssh\""
    action :run
  end

  template "/home/#{sftp_site[:download][:user]}/.ssh/authorized_keys" do
    backup false
    source 'authorized_keys.erb'
    owner sftp_site[:download][:user]
    group user_group
    variables :public_key => sftp_site[:download][:public_key]
    mode 0600
  end



  base_repo = File.join(sftp_base_dir, sftp_site[:home])
  execute "create sftp repo #{base_repo}" do
    command "sudo mkdir #{base_repo}"
    action :run
  end


  # Download Folder
  download_dir = File.join(base_repo, sftp_site[:download][:folder])
  execute "create sftp repo #{download_dir}" do
    command "sudo mkdir #{download_dir}"
    action :run
  end

  execute "chown #{download_dir}" do
    command "sudo chown #{sftp_site[:download][:user]}:#{user_group} #{download_dir}"
    action :run
  end

  execute "chmod #{download_dir}" do
    command "sudo chmod #{node[:sftp_permission]} -R #{download_dir}"
    action :run
  end


  # Upload Folder
  upload_dir = File.join(base_repo, sftp_site[:folder_upload])
  execute "create sftp repo #{upload_dir}" do
    command "sudo mkdir #{upload_dir}"
    action :run
  end
  execute "chown #{upload_dir}" do
    command "sudo chown #{sftp_site[:download][:user]}:#{user_group} #{upload_dir}"
    action :run
  end

  execute "chmod #{upload_dir}" do
    command "sudo chmod #{node[:sftp_permission]} -R #{upload_dir}"
    action :run
  end

  sftp_site[:upload].each do |user|
    execute "add user #{user[:user]}" do
      command "sudo adduser #{user[:user]} -g #{user_group}"
      action :run
    end
    execute "add .ssh dir for user #{user[:user]}" do
      command "sudo su - #{user[:user]} -c \"mkdir .ssh\""
      action :run
    end
    execute "chmod .ssh dir for user #{user[:user]}" do
      command "sudo su - #{user[:user]} -c \"chmod 700 .ssh\""
      action :run
    end
    template "/home/#{user[:user]}/.ssh/authorized_keys" do
      backup false
      source 'authorized_keys.erb'
      owner user[:user]
      user_group
      variables :public_key => user[:public_key]
      mode 0600
    end
  end

end

service "sshd" do
  action :restart
end

