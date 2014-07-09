#
# Cookbook Name:: awesome_appliance_repair
# Recipe:: default
#
# Copyright (C) 2014 
#
# 
#

# # The following script assumes that apache2, mysql, and unzip have been installed.
["apache2", "mysql-server", "unzip"].each do |p|
  package p
end

# # 1. wget https://github.com/colincam/Awesome-Appliance-Repair/archive/master.zip
github_organization = "nathenharvey"

remote_file "#{Chef::Config[:file_cache_path]}/master.zip" do
  source "https://github.com/#{github_organization}/Awesome-Appliance-Repair/archive/master.zip"
  notifies :run, "execute[unzip master.zip]"
end

# # 2. unzip master.zip
execute "unzip master.zip" do
  command "unzip #{Chef::Config[:file_cache_path]}/master.zip"
  cwd Chef::Config[:file_cache_path]
  not_if do
    File.exists? "#{Chef::Config[:file_cache_path]}/Awesome-Appliance-Repair-master/README.md"
  end
  notifies :create, "directory[/var/www]"
  notifies :run, "execute[mv AAR to /var/www]"
end

# # 3. cd into Awesome-Appliance-Repair
# # 4. sudo mv AAR to /var/www/
directory "/var/www"

execute "mv AAR to /var/www" do
  cwd "#{Chef::Config[:file_cache_path]}/Awesome-Appliance-Repair-master"
  command "mv AAR /var/www/"
  not_if do
    File.exists? "/var/www/AAR/robots.txt"
  end
end

# if __name__ == '__main__':
#     root_dbpswd = getpass.getpass('enter the mysql root user password: ')

#     Popen(['chown', '-R', 'www-data:www-data', '/var/www/AAR'], shell=False).wait()
execute "chown /var/www/AAR" do
  command "chown -R www-data:www-data /var/www/AAR"
  only_if do
    # check if a given file is owned by root
    File.stat("/var/www/AAR/awesomeapp.py").uid == 0 || File.stat("/var/www/AAR/awesomeapp.py").gid == 0
  end
end


# # apt-get the stuff we need    
#     proc = Popen([
#         'apt-get', 'install', '-y',
#         'libapache2-mod-wsgi',
#         'python-pip',
#         'python-mysqldb'], shell=False)
#     proc.wait()

['libapache2-mod-wsgi', 'python-pip', 'python-mysqldb'].each do |p|
  package p
end

# # pip install flask
#     Popen(['pip', 'install', 'flask'], shell=False).wait()
execute "pip install flask" do
  not_if "pip show Flask | grep Flask"
end

# # Generate the apache config file in sites-enabled
template "/etc/apache2/sites-enabled/AAR-apache.conf" do
  notifies :reload, "service[apache2]"
end

# TODO:  shoudl use better password and secretkey
appdbpw = "password"
template "/var/www/AAR/AAR_config.py" do
  variables(
    :appdbpw => appdbpw,
    :secretkey => "mysecretkey"
  )
end

execute "create db, user, and permissions" do
  cwd "#{Chef::Config[:file_cache_path]}/Awesome-Appliance-Repair-master"
  command "mysql -u root < make_AARdb.sql"
  not_if "mysql -u root -e \"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'AARdb'\" | grep AARdb"
end

execute "create user" do
  command "mysql -u root -D AARdb -e \"CREATE USER 'aarapp'@'localhost' IDENTIFIED BY '#{appdbpw}'\""
  not_if "mysql -u root -D mysql -e \"select host, user from user where host = 'localhost' and user = 'aarapp'\" | grep aarapp"
end

execute "grant access to database" do
  command "mysql -u root -D AARdb -e \"GRANT CREATE,INSERT,DELETE,UPDATE,SELECT on AARdb.* to aarapp@localhost\""
  not_if "mysql -u root -e \"show grants for 'aarapp'@'localhost'\" | grep GRANT | grep CREATE | grep INSERT | grep DELETE | grep UPDATE | grep SELECT"
end

# # 7. manually execute: apachectl graceful
service "apache2" do
  supports :reload => true
  action :nothing
end