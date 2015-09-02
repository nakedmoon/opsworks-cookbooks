node[:deploy].each do |application, deploy|

  package 'php soap' do
    package_name 'php-soap'
    action :install
  end

  include_recipe 'apache2::service'

  service 'apache2' do
    action :restart
  end


end

