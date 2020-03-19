action :create do
  Chef::Log.info "Creating hdfs directory: #{@new_resource.name}"

  recursive="-p"
  if new_resource.recursive == false
      recursive=""
  end
  bash "mk-dir-#{new_resource.name}" do
    user "#{new_resource.owner}"
    group "#{new_resource.group}"
    code <<-EOF
     . #{node['hops']['base_dir']}/sbin/set-env.sh
     #{node['hops']['base_dir']}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     if [ $? -ne 0 ] ; then
        sleep 10
        #{node['hops']['base_dir']}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     fi
     #{node['hops']['base_dir']}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.name}
     if [ "#{new_resource.mode}" != "" ] ; then
        #{node['hops']['base_dir']}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.name}
     fi
    EOF
  not_if "su -c #{new_resource.owner} \". #{node['hops']['base_dir']}/sbin/set-env.sh && #{node['hops']['base_dir']}/bin/hdfs dfs -test -d #{new_resource.name}\""
  end

end

action :put do
  Chef::Log.info "Putting file(s) from directory #{@new_resource.name} into hdfs directory #{@new_resource.dest}"

  bash "hdfs-put-dir-#{new_resource.name}" do
    user "#{new_resource.owner}"
    group "#{new_resource.group}"
    code <<-EOF
     . #{node['hops']['base_dir']}/sbin/set-env.sh
     #{node['hops']['base_dir']}/bin/hdfs dfs -test -e #{new_resource.dest}
     if [ $? -ne 0 ] ; then
        #{node['hops']['base_dir']}/bin/hdfs dfs -copyFromLocal #{new_resource.name} #{new_resource.dest}
        #{node['hops']['base_dir']}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.dest}
        if [ "#{new_resource.mode}" != "" ] ; then
           #{node['hops']['base_dir']}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.dest}
        fi
     fi
    EOF
  end

end


action :put_as_superuser do
  Chef::Log.info "Putting file(s) #{@new_resource.isDir} from directory #{@new_resource.name} into hdfs directory #{@new_resource.dest}"

  # HDFS operation will be done with group HDFS because the client
  # needs to be able to access hdfs user certificates
  # So stage them first and chgrp to hdfs before putting them to hdfs
  stagingDir = "#{Chef::Config['file_cache_path']}/hdfs_directory_staging"
  directory stagingDir do
    owner node['hops']['hdfs']['user']
    group node['hops']['group']
    mode "0770"
    action :create
  end
  
  basename = ::File.basename(new_resource.name)
  bash "stage-file" do
    user "root"
    group "root"
    code <<-EOH
      cp -rf #{new_resource.name} #{stagingDir}/#{basename}
      chgrp -R #{node['hops']['hdfs']['group']} #{stagingDir}/#{basename}
    EOH
  end

  bash "hdfs-put-dir-#{new_resource.name}" do
    user node['hops']['hdfs']['user']
    group node['hops']['hdfs']['group']
    code <<-EOF
     EXISTS=1
     . #{node['hops']['base_dir']}/sbin/set-env.sh
     if [ -z $ISDIR ] ; then
        #{node['hops']['base_dir']}/bin/hdfs dfs -test -e #{new_resource.dest}
        EXISTS=$?
     else
        #{node['hops']['base_dir']}/bin/hdfs dfs -test -f #{new_resource.dest}
        EXISTS=$?
     fi
     if ([ $EXISTS -ne 0 ] || [ #{new_resource.isDir} ]) ; then
        #{node['hops']['base_dir']}/bin/hdfs dfs -copyFromLocal #{stagingDir}/#{basename} #{new_resource.dest}
        #{node['hops']['base_dir']}/bin/hdfs dfs -chown #{new_resource.owner} #{new_resource.dest}
        #{node['hops']['base_dir']}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.dest}
        if [ "#{new_resource.mode}" != "" ] ; then
           #{node['hops']['base_dir']}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.dest}
        fi
     fi
    EOF
    notifies :run, 'bash[delete-stage]', :immediately
  end

  bash "delete-stage" do
    user "root"
    group "root"
    code <<-EOH
      rm -rf #{stagingDir}/#{basename}
    EOH
    action :nothing
  end
end


action :create_as_superuser do
  Chef::Log.info "Putting hdfs file: #{@new_resource.name}"

  recursive="-p"
  if new_resource.recursive == false
      recursive=""
  end

  bash "mk-dir-#{new_resource.name}" do
    user node['hops']['hdfs']['user']
    group node['hops']['hdfs']['group']
    retries 1
    code <<-EOF
     . #{node['hops']['base_dir']}/sbin/set-env.sh
     #{node['hops']['base_dir']}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     if [ $? -ne 0 ] ; then
        sleep 10
        #{node['hops']['base_dir']}/bin/hdfs dfs -mkdir #{recursive} #{new_resource.name}
     fi
     #{node['hops']['base_dir']}/bin/hdfs dfs -chown #{new_resource.owner} #{new_resource.name}
     #{node['hops']['base_dir']}/bin/hdfs dfs -chgrp #{new_resource.group} #{new_resource.name}
     if [ "#{new_resource.mode}" != "" ] ; then
        #{node['hops']['base_dir']}/bin/hadoop fs -chmod #{new_resource.mode} #{new_resource.name}
     fi
    EOF
  not_if "su #{node['hops']['hdfs']['user']} -c \". #{node['hops']['base_dir']}/sbin/set-env.sh && #{node['hops']['base_dir']}/bin/hdfs dfs -test -d #{new_resource.name}\""
  end

end

action :rm_as_superuser do

  Chef::Log.info "Removing hdfs file: #{@new_resource.name}"

  recursive="-r"
  if new_resource.recursive == false
      recursive=""
  end

  bash "rm-#{new_resource.name}" do
    user node['hops']['hdfs']['user']
    group node['hops']['hdfs']['group']
    ignore_failure true
    code <<-EOF
     . #{node['hops']['base_dir']}/sbin/set-env.sh
     #{node['hops']['base_dir']}/bin/hdfs dfs -rm #{recursive} #{new_resource.name}
     if [ $? -ne 0 ] ; then
        sleep 5
        #{node['hops']['base_dir']}/bin/hdfs dfs -rm -f #{recursive} #{new_resource.name}
     fi
    EOF
  only_if "su #{node['hops']['hdfs']['user']} -c \"#{node['hops']['base_dir']}/bin/hdfs dfs -test -e #{new_resource.name}\""
  end

end


action :replace_as_superuser do

  hops_hdfs_directory "#{new_resource.dest}" do
    recursive true
    action :rm_as_superuser
  end

  hops_hdfs_directory "#{new_resource.name}" do
    owner "#{new_resource.owner}"
    group "#{new_resource.group}"
    mode "#{new_resource.mode}"
    dest "#{new_resource.dest}"
    action :put_as_superuser
  end

end
