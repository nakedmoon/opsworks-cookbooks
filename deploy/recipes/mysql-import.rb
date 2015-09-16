require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|

  mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"
  mysql_dump_f = "mysqldump -h %s --user=%s --password=%s --add-drop-table --skip-lock-tables --routines  --single-transaction --quick %s | %s %s"
  instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}.push('localhost')


  deploy[:database][:hyena_db_users].each do |user|
    current_user = user[:username]
    current_password = user[:password]
    user_ips = instances_ips.push(*user[:ips])

    user_ips.each do |ip|
      execute "create user #{current_user}@#{ip}" do
        sql_user = Array.new.tap do |sql|
          sql << "GRANT USAGE ON *.* TO '#{current_user}'@'#{ip}';"
          sql << "DROP USER '#{current_user}'@'#{ip}';"
          sql << "CREATE USER '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
        end.join
        command "#{mysql_command} -e \"#{sql_user}\" "
      end
    end

  end

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

    deploy[:database][:hyena_db_users].each do |user|
      current_user = user[:username]
      current_password = user[:password]
      user_ips = instances_ips.push(*user[:ips])

      user_ips.each do |ip|
        execute "grant all privileges on #{db} for user #{current_user}@#{ip}" do
          sql_grant = Array.new.tap do |sql|
            sql << "GRANT ALL ON #{db}.* TO '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
            sql << "FLUSH PRIVILEGES;"
          end.join
          command "#{mysql_command} -e \"#{sql_grant}\" "
        end
      end

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

    log "#{db} import message" do
      message "Database #{db} imported from #{node[:mysql_import][:host]}@#{origin}"
      level :info
    end


  end

end


