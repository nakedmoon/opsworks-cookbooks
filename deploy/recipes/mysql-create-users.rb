require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|

  mysql_command = "#{node[:mysql][:mysql_bin]} -u root -p#{node[:mysql][:root_password]}"

  current_user = deploy[:wp][:db_user]
  current_password = deploy[:wp][:db_password]
  instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}
  user_ips = instances_ips.push(*deploy[:wp][:user_ips]).unshift('localhost')
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


  ['uploads','plugins','plugins/widgetkit/cache','themes/yoo_unity_wp/cache'].each do |d|
    dir = File.join(node[:deploy][application][:deploy_to], 'current', 'wp-content')
    execute "chmodding 755 directory #{dir}" do
      command "chmod 755 #{dir}"
    end
  end


end


