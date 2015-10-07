group 'opsworks'

node[:sftp_sites].each do |name, sftp|
  template "/home/deploy/.ssh/#{name}.pem" do
    backup false
    source 'sftp.pem.erb'
    owner node[:deploy][:user]
    group node[:deploy][:group]
    mode 0440
    variables :private_key => sftp[:private_key]
  end
end