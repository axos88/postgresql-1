# frozen_string_literal: true
#
# Cookbook:: postgresql
# Recipe:: server
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Chef::Log.warn 'This cookbook is being re-written to use resources, not recipes and will only be Chef 13.8+ compatible. Please version pin to 6.1.1 to prevent the breaking changes from taking effect. See https://github.com/sous-chefs/postgresql/issues/512 for details'

change_notify = node['postgresql']['server']['config_change_notify']

# There are some configuration items which depend on correctly evaluating the intended version being installed
if node['platform_family'] == 'debian'

  node.normal['postgresql']['config']['hba_file'] = "/etc/postgresql/#{node['postgresql']['version']}/main/pg_hba.conf"
  node.normal['postgresql']['config']['ident_file'] = "/etc/postgresql/#{node['postgresql']['version']}/main/pg_ident.conf"
  node.normal['postgresql']['config']['external_pid_file'] = "/var/run/postgresql/#{node['postgresql']['version']}-main.pid"

  if node['postgresql']['version'].to_f < 9.3
    node.normal['postgresql']['config']['unix_socket_directory'] = '/var/run/postgresql'
  else
    node.normal['postgresql']['config']['unix_socket_directories'] = '/var/run/postgresql'
  end

  if node['postgresql']['config']['ssl']
    node.normal['postgresql']['config']['ssl_cert_file'] = '/etc/ssl/certs/ssl-cert-snakeoil.pem' if node['postgresql']['version'].to_f >= 9.2
    node.normal['postgresql']['config']['ssl_key_file'] = '/etc/ssl/private/ssl-cert-snakeoil.key' if node['postgresql']['version'].to_f >= 9.2
  end

end

directory node['postgresql']['dir'] do
  recursive true
  owner 'postgres'
  group 'postgres'
  mode 0700
end

directory node['postgresql']['config']['data_directory'] do
  recursive true
  owner 'postgres'
  group 'postgres'
  mode 0700
end

execute 'Init DB' do
  user 'postgres'

  command "export LC_ALL=C; /usr/lib/postgresql/#{node['postgresql']['version']}/bin/pg_ctl -D '#{node['postgresql']['config']['data_directory']}' initdb"
  action :run
  not_if { ::File.exist?(File.join(node['postgresql']['config']['data_directory'], 'PG_VERSION')) }
end

template "#{node['postgresql']['dir']}/postgresql.conf" do
  source 'postgresql.conf.erb'
  owner 'postgres'
  group 'postgres'
  mode '0600'
  notifies change_notify, 'service[postgresql]', :immediately
end

template "#{node['postgresql']['dir']}/pg_hba.conf" do
  source 'pg_hba.conf.erb'
  owner 'postgres'
  group 'postgres'
  mode '0600'
  notifies change_notify, 'service[postgresql]', :immediately
end

template node['postgresql']['config']['ident_file'] do
  source "pg_ident.conf.erb"
  owner "postgres"
  group "postgres"
  mode 00600
  notifies change_notify, 'service[postgresql]', :delayed

  not_if { node['postgresql']['ident_maps'].nil? }
end