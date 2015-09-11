require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u root -p#{deploy[:database][:root_password]}"

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
      s3_cmds << "sudo aws s3 cp s3://fit2youdumps/#{db}.sql.gz ."
      s3_cmds << "sudo gzip -d #{db}.sql.gz"
      s3_cmds << "#{mysql_command} #{db} < #{db}.sql"
      s3_cmds << "sudo rm -f #{db}.sql"
      command s3_cmds.join(";")
      action :run
    end


    log "#{db} import message" do
      message "Database #{db} imported from s3://fit2youdumps/#{db}.sql.gz"
      level :info
    end


  end

end


