require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u root -p#{node[:mysql][:root_password]}"

  current_user = deploy[:database][:wp_db_user]
  current_password = deploy[:database][:wp_db_password]
  instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}
  user_ips = instances_ips.push(*deploy[:database][:wp_db_user_ips]).unshift('localhost')
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


  node[:mysql_import][:databases].each do |origin, db|
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


end


