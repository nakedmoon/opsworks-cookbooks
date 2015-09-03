require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"

  node[:mysql_import][:databases].each do |origin, db|

    current_user = deploy[:database][:hyena_db_user][:username]
    current_password = deploy[:database][:hyena_db_user][:password]
    instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}
    (instances_ips + deploy[:database][:hyena_db_user][:ips]).each do |ip|
      execute "grant all privileges on #{db} for user #{current_user}@#{ip}" do
        sql_users = Array.new.tap do |sql|
          sql << "GRANT USAGE ON *.* TO '#{current_user}'@'#{ip}';"
          sql << "DROP USER '#{current_user}'@'#{ip}';"
          sql << "FLUSH PRIVILEGES;"
          sql << "CREATE USER '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
          sql << "GRANT ALL ON #{db}.* TO '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
          sql << "FLUSH PRIVILEGES;"
        end.join
        command "#{mysql_command} -e \"#{sql_users}\" "
      end
    end

  end


end


