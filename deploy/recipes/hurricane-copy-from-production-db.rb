include_recipe 'deploy'
Chef::Log.level = :debug

node[:deploy].first(1).each do |application, deploy|

  production_database = node[:hurricane_api_settings][:production_database]

  if deploy[:rails_env] == 'staging'


    dump_dir = "#{deploy[:deploy_to]}/shared/dump"
    dump_file = [dump_dir, 'snapshot_production.sql'].join('/')
    truncate_tables_sql_file = [dump_dir, 'truncate_table.sql'].join('/')
    staging_database = deploy[:database]

    sql = <<-SQL
    do
    $$
    declare
      truncate_tables_query text;
    begin
      select 'truncate ' || string_agg(format('%I.%I', schemaname, tablename), ',') || ' RESTART IDENTITY CASCADE'
        into truncate_tables_query
      from pg_tables
      where schemaname in ('public') and tableowner = '#{staging_database[:username]}' and tablename != 'schema_migrations';
      execute truncate_tables_query;
    end;
    $$
    SQL

    directory dump_dir do
      mode '0770'
      owner deploy[:user]
      group deploy[:group]
      action :create
      recursive true
    end

    execute 'dump production database' do
      Chef::Log.debug('Dump Production Database')
      user deploy[:user]
      environment 'PGPASSWORD' => production_database[:password]
      cwd dump_dir
      dump_cmd = 'pg_dump -h %s --data-only --no-owner --exclude-table-data=schema_migrations -x -U %s %s > %s'
      command sprintf(dump_cmd, production_database[:host], production_database[:username], production_database[:database], dump_file)
      action :run
    end

    file truncate_tables_sql_file do
      content sql
      mode '0660'
      owner deploy[:user]
    end

    execute 'truncate tables' do
      Chef::Log.debug('Truncate Staging Database Tables')
      user deploy[:user]
      environment 'PGPASSWORD' => staging_database[:password]
      cwd dump_dir
      truncate_cmd = 'psql -h %s -d %s -U %s < %s'
      command sprintf(truncate_cmd, staging_database[:host], staging_database[:database], staging_database[:username], truncate_tables_sql_file)
      action :run
    end

    execute 'copy into staging database' do
      Chef::Log.debug('Copy Into Staging Database')
      user deploy[:user]
      environment 'PGPASSWORD' => staging_database[:password]
      cwd dump_dir
      restore_cmd = 'psql -h %s -d %s -U %s < %s'
      command sprintf(restore_cmd, staging_database[:host], staging_database[:database], staging_database[:username], dump_file)
      action :run
    end


    execute 'update user dealer password' do
      Chef::Log.debug('Updating user passowrd')
      user deploy[:user]
      environment 'PGPASSWORD' => staging_database[:password]
      update_cmd = "UPDATE users SET encrypted_password = '$2a$10$dnweS3sLpXy2/n2Qhc16yOY9hM7ew46CertcGQW1iW8q02NzBfMs6' WHERE email = 'info@fit2you.it'"
      command sprintf(
                  "psql -h %s -d %s -U %s -c '%s'",
                  staging_database[:host],
                  staging_database[:database],
                  staging_database[:username],
                  update_cmd
              )
      action :run


    end

    file dump_file do
      Chef::Log.debug('Remove Sql Dump')
      action :delete
    end

    file truncate_tables_sql_file do
      Chef::Log.debug('Remove Sql Truncate File')
      action :delete
    end

    execute 'rake db:migrate' do
      Chef::Log.debug('Execute Rails Db Migrate')
      cwd "#{deploy[:deploy_to]}/current"
      user deploy[:user]
      command 'bundle exec rake db:migrate'
      environment 'RAILS_ENV' => deploy[:rails_env]
    end


  else
    Chef::Log.debug('Recipe available only in staging environment')
  end

end
