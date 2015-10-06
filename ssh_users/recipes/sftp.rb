group 'opsworks'

template '/etc/ssh/sshd_config' do
  backup false
  source 'sshd_config.erb'
  owner 'root'
  group 'root'
  variables :sftp_sites => node[:sftp_sites]
  mode 0440
end

sftp_base_dir = "/var/sftp/sites"

execute "create sftp base dir #{sftp_base_dir}" do
  command "sudo mkdir -p #{sftp_base_dir}"
  action :run
end

node[:sftp_sites].each do |sftp_site|
  execute "add user #{sftp_site[:upload][:user]}" do
    command "sudo adduser #{sftp_site[:upload][:user]}"
    action :run
  end
  execute "add user #{sftp_site[:download][:user]}" do
    command "sudo adduser #{sftp_site[:download][:user]}"
    action :run
  end

  execute "add .ssh dir for user #{sftp_site[:download][:user]}" do
    command "sudo su - #{sftp_site[:download][:user]} -c \"mkdir .ssh\""
    action :run
  end

  execute "add .ssh dir for user #{sftp_site[:upload][:user]}" do
    command "sudo su - #{sftp_site[:upload][:user]} -c \"mkdir .ssh\""
    action :run
  end

  execute "chmod .ssh dir for user #{sftp_site[:upload][:user]}" do
    command "sudo su - #{sftp_site[:upload][:user]} -c \"chmod 700 .ssh\""
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
    group sftp_site[:download][:user]
    variables :public_key => sftp_site[:download][:public_key]
    mode 0600
  end

  template "/home/#{sftp_site[:upload][:user]}/.ssh/authorized_keys" do
    backup false
    source 'authorized_keys.erb'
    owner sftp_site[:upload][:user]
    group sftp_site[:upload][:user]
    variables :public_key => sftp_site[:upload][:public_key]
    mode 0600
  end

  base_repo = File.join(sftp_base_dir, sftp_site[:home])
  execute "create sftp repo #{base_repo}" do
    command "sudo mkdir #{base_repo}"
    action :run
  end


  # Download Folder
  download_dir = File.join(base_repo, "download")
  execute "create sftp repo #{download_dir}" do
    command "sudo mkdir #{download_dir}"
    action :run
  end

  execute "chown #{download_dir}" do
    command "sudo chown #{sftp_site[:download][:user]}:#{sftp_site[:upload][:user]} #{download_dir}"
    action :run
  end

  execute "chmod #{download_dir}" do
    command "sudo chmod 0750 -R #{download_dir}"
    action :run
  end


  # Upload Folder
  upload_dir = File.join(base_repo, "upload")
  execute "create sftp repo #{upload_dir}" do
    command "sudo mkdir #{upload_dir}"
    action :run
  end

  execute "chown #{upload_dir}" do
    command "sudo chown #{sftp_site[:upload][:user]}:#{sftp_site[:download][:user]} #{upload_dir}"
    action :run
  end

  execute "chmod #{upload_dir}" do
    command "sudo chmod 0750 -R #{upload_dir}"
    action :run
  end



end

service "sshd" do
  action :restart
end

