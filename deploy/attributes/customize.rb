###
# This is the place to override the deploy cookbook's default attributes.
#
# Do not edit THIS file directly. Instead, create
# "deploy/attributes/customize.rb" in your cookbook repository and
# put the overrides in YOUR customize.rb file.
###

# The following shows how to override the deploy user and shell:
#
#normal[:opsworks][:deploy_user][:shell] = '/bin/zsh'
#normal[:opsworks][:deploy_user][:user] = 'deploy'
normal[:opsworks][:rails_stack][:start_command] = "../../shared/scripts/unicorn start"
normal[:opsworks][:rails_stack][:stop_command] = "../../shared/scripts/unicorn stop"
