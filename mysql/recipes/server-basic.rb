require 'resolv'

include_recipe 'mysql::client'
include_recipe 'mysql::prepare'

# for backwards compatiblity default the package name to mysql
mysql_name = node[:mysql][:name] || "mysql"

package "#{mysql_name}-server"

include_recipe 'mysql::service'

service "mysql" do
  action :enable
end

service "mysql" do
  action :start
end

execute "root password" do
  command "mysql -uroot -e \"SET PASSWORD=PASSWORD('#{node[:mysql][:root_password]}');\""
end
