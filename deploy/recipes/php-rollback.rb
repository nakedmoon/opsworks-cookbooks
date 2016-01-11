node[:deploy].each do |application, deploy|

  if deploy[:application_type] != 'php'
    Chef::Log.debug("Skipping deploy::php-rollback application #{application} as it is not a PHP app")
    next
  end

  deploy deploy[:deploy_to] do
    user deploy[:user]
    action "rollback"
    only_if do
      File.exists?(deploy[:current_path])
    end
  end

end