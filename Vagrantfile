# -*- mode: ruby -*-
# vi: set ft=ruby : 

require 'yaml'

# Vagrantfile API/syntax version.  Don't touch unless you know what you're doing! 
VAGRANTFILE_API_VERSION = "2" 

# Sets vmware fusion as the default provider 
ENV['VAGRANT_DEFAULT_PROVIDER'] = "virtualbox"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config| 

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "neu_libraries/plattr" 

  # Custom configuration goes here.
  if File.exists?("requirements/local/vagrant_conf.yml")
    custom_config = YAML.load_file(File.open("requirements/local/vagrant_conf.yml"))

    unless custom_config.is_a? Hash 
      raise "YAML parser returned a #{custom_config.class} instead of a Hash - "\
        "This likely means that your YAML config is invalid"
    end
  else
    custom_config = {} 
  end

  # Apply defaults 
  custom_config["tapas_rails_directory"] ||= "~/tapas_rails"
  custom_config["drupal_share_directory"] ||= "~/tapas-drupal"

  # Set the branch of buildtapas (github.com/neu-dsg/buildtapas) to use when building
  # the site.  Check command line arguments first, then the custom_config hash, then 
  # default to develop.
  tapas_branch = ENV['BUILDTAPAS_BRANCH'] || 
    custom_config['buildtapas_branch'] || 
    'develop'


  # Caches yum packages to cut down on install time after the first 
  # build.  Note that cached packages will be reused for any other 
  # chef/centos-6.5 boxes.
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  # Forward 8080, which Apache is listening on (serves drupal site)
  config.vm.network :forwarded_port, guest: 8080, host: 8080, auto_correct: true 

  # Forward local fedora/solr instances on this port
  config.vm.network :forwarded_port, guest: 8983, host: 8986, auto_correct: true

  # Forward eXist instance
  config.vm.network :forwarded_port, guest: 8868, host: 8848, auto_correct: true

  # If true, then any SSH connections made will enable agent forward.
  # Default value: false
  config.ssh.forward_agent = true 

  # Don't attempt to insert a secure keypair
  config.ssh.insert_key = false

  # Optimizations for vmware_fusion machines
  config.vm.provider "vmware_fusion" do |vm|
    vm.customize ['modifyvm', :id, '--memory', '3072', '--cpus', '4', '--natdnsproxy1', 'off', '--natdnshostresolver1', 'off', '--ioapic', 'on']
    vm.vmx["memsize"] = "4072"
    vm.vmx["numvcpus"] = "4"
  end

  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", '5734']
    vb.customize ["modifyvm", :id, "--ioapic", 'on']
    vb.customize ["modifyvm", :id, "--cpus", '4']
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
  end

  ENV["USER_ID"] = Process.uid.to_s

  config.vm.provision "shell" do |s| 
    s.path = "scripts/plattr_provisioning.sh"
    s.privileged = false
    s.args = ["\"#{ENV['USER_ID']}\" \"#{tapas_branch}\""]
  end

  config.vm.synced_folder custom_config["tapas_rails_directory"], "/home/vagrant/tapas_rails", nfs: true
  config.vm.synced_folder custom_config["drupal_share_directory"], "/var/www/html", nfs: true
  config.vm.synced_folder ".", "/vagrant", :type => "nfs"

  config.vm.network "private_network", ip: "192.168.3.6"
end
