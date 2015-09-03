require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"
  mysql_dump_f = "mysqldump -h %s --user=%s --password=%s --add-drop-table %s | %s %s"

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

    execute "import remote database #{db}" do
      mysql_dump_command = sprintf(mysql_dump_f, node[:mysql_import][:host],
                                   node[:mysql_import][:username],
                                   node[:mysql_import][:password],
                                   origin, mysql_command, db
      )
      command mysql_dump_command
      action :run
    end

    deploy[:database][:hyena_db_user][:ips].each do |ip|
      execute "grant all privileges on #{db} for user #{deploy[:database][:hyena_db_user][:username]}@#{ip}" do
        sql_users = Array.new.tap do |sql|
          sql << "CREATE USER `#{deploy[:database][:hyena_db_user][:username]}`@`#{ip}` IDENTIFIED BY '#{deploy[:database][:hyena_db_user][:password]}';"
          sql << "GRANT ALL ON #{db}.* TO `#{deploy[:database][:hyena_db_user][:username]}`@`#{ip}`;"
        end.join
        command "#{mysql_command} -e '#{sql_users}' "
      end
    end



    log "#{db} import message" do
      message "Database #{db} imported from #{node[:mysql_import][:host]}@#{origin}"
      level :info
    end


  end

  execute "flush privileges" do
    command "#{mysql_command} -e 'FLUSH PRIVILEGES;' "
    action :run
  end





end


