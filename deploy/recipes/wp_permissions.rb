require 'resolv'
include_recipe 'deploy'

Chef::Log.level = :debug

node[:deploy].each do |application, deploy|

  ['uploads','plugins','plugins/widgetkit/cache','themes/yoo_unity_wp/cache'].each do |d|
    dir = File.join(node[:deploy][application][:deploy_to], 'current', 'wp-content', d)
    execute "chmodding 755 directory #{dir}" do
      command "chmod 755 #{dir}"
    end
  end


end


