require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"

  node[:mysql_import][:databases].each do |origin, db|

    instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}
    (instances_ips + deploy[:database][:hyena_db_user][:ips]).each do |ip|
      current_user = deploy[:database][:hyena_db_user][:username]
      current_password = deploy[:database][:hyena_db_user][:password]
      execute "grant all privileges on #{db} for user #{current_user}@#{ip}" do
        sql_users = Array.new.tap do |sql|
          sql << "DELETE FROM mysql.user WHERE User = '#{current_user}' AND Host = '#{ip}';FLUSH PRIVILEGES;"
          sql << "CREATE USER '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
          sql << "GRANT ALL ON #{db}.* TO '#{current_user}'@'#{ip}' IDENTIFIED BY '#{current_password}';"
        end.join
        command "#{mysql_command} -e \"#{sql_users}\" "
      end
    end

  end

  execute "flush privileges" do
    command "#{mysql_command} -e 'FLUSH PRIVILEGES;' "
    action :run
  end





end


