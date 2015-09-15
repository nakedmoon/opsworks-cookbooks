require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|

  mysql_command = "#{node[:mysql][:mysql_bin]} -u root -p#{node[:mysql][:root_password]}"
  #mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"
  mysql_definer_filter = "sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/'"

  node[:mysql_import][:databases].each do |origin, db|
    execute "drop database #{db}" do
      command "#{mysql_command} -e 'DROP DATABASE `#{db}`' "
      action :run

      only_if do
        system("#{mysql_command} -e 'SHOW DATABASES' | egrep -e '^#{db}$'")
      end
    end

    execute "create database #{db}" do
      command "#{mysql_command} -e 'CREATE DATABASE `#{db}`' "
      action :run
    end

    execute "import s3 dump #{db}" do
      cwd "/tmp"
      s3_cmds = []
      s3_cmds << "sudo aws s3 cp s3://#{node[:mysql_import][:s3_bucket]}/#{db}.sql.gz ."
      s3_cmds << "sudo gzip -d #{db}.sql.gz"
      s3_cmds << "cat #{db}.sql | #{mysql_definer_filter} | #{mysql_command} #{db}"
      s3_cmds << "sudo rm -f #{db}.sql"
      command s3_cmds.join(";")
      action :run
    end


    log "#{db} import message" do
      message "Database #{db} imported from s3://#{node[:mysql_import][:s3_bucket]}/#{db}.sql.gz"
      level :info
    end


  end

end


