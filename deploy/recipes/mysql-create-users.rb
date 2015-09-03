require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|
  next if deploy[:database].nil? || deploy[:database].empty?

  mysql_command = "#{node[:mysql][:mysql_bin]} -u #{deploy[:database][:username]} #{node[:mysql][:server_root_password].blank? ? '' : "-p#{node[:mysql][:server_root_password]}"}"
  mysql_dump_f = "mysqldump -h %s --user=%s --password=%s --add-drop-table %s | %s %s"

  node[:mysql_import][:databases].each do |origin, db|

    log "====LOG====" do
      message node[:opsworks].inspect
      level :info
    end

    instances_ips = node["opsworks"]["layers"]["php-app"]["instances"].values.map{|i| i.fetch("private_ip")}
    (instances_ips + deploy[:database][:hyena_db_user][:ips]).each do |ip|
      execute "grant all privileges on #{db} for user #{deploy[:database][:hyena_db_user][:username]}@#{ip}" do
        sql_users = Array.new.tap do |sql|
          sql << "CREATE USER '#{deploy[:database][:hyena_db_user][:username]}'@'#{ip}' IDENTIFIED BY '#{deploy[:database][:hyena_db_user][:password]}';"
          sql << "GRANT ALL ON #{db}.* TO '#{deploy[:database][:hyena_db_user][:username]}'@'#{ip}' IDENTIFIED BY '#{deploy[:database][:hyena_db_user][:password]}';"
        end.join
        command "#{mysql_command} -e '#{sql_users}' "
      end
    end

  end

  execute "flush privileges" do
    command "#{mysql_command} -e 'FLUSH PRIVILEGES;' "
    action :run
  end





end


