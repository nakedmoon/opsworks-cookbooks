group 'opsworks'

node[:deploy].each do |application, deploy|

  node[:sftp_sites].each do |name, sftp|
    template "/home/deploy/.ssh/#{name}.pem" do
      backup false
      source 'sftp.pem.erb'
      owner deploy[:user]
      group deploy[:group]
      mode 0440
      variables :private_key => sftp[:private_key]
    end
  end



end

