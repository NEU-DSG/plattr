Plattr
=======

Isn't fancy or interesting or even really a proper project.  It's just a Vagrant config that can/should allow everyone associated with TAPAS development to work from a preconfigured box.  Currently a work in progress.

## Installation Instructions 

1. Ensure that you have the correct versions of [Vagrant](http://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) on your machine.  Vagrant can be downloaded [here](https://www.vagrantup.com/downloads.html) and Virtualbox can be downloaded [here](https://www.virtualbox.org/wiki/Downloads).  Use Vagrant **1.7.2** and VirtualBox **4.3.28**.  While other versions should work, note that they may introduce bugs.  Flux w/r/t VirtualBox versions seems to be especially bad for this.  
    * For a significant speed increase during vagrant creation, install the vagrant-cachier plugin.  Documentation [here](https://github.com/fgrehm/vagrant-cachier).  The command is ``vagrant plugin install vagrant-cachier``
2. Clone the repository down: ``git clone https://github.com/neu-dsg/plattr.git``
3. Ensure that within the plattr directory, you create a requirements/local directory 
3. Clone the tapas_rails repository down: ``git clone https://github.com/neu-dsg/tapas_rails.git``
    * For a significant speed increase during vagrant up, run ``bundle package`` from inside the tapas_rails directory.  This will cache the gems specified by the project Gemfile into vendor/cache and eliminate the need to dl them from inside your Vagrant box.  Note that you need to have ruby installed and the bundler gem available for this to do anything.
4. Ensure that whichever directory you intend to share the built Drupal site to (defaults to ~/tapas-drupal) exists on your host system. 
5.  There is one file not in VC that is required for the project to run.  Ask me (@jbuckle) for the application.yml file and then place it at ~/tapas_rails/config/
6. CD into the root directory of the project and run ``vagrant up``.  Be patient - installation takes time. 
7. Type ``vagrant ssh`` and you should be ssh'd directly into the machine.  Since none of the components talk to each other (yet) this is everything you need to do.  Do note that the Rails server isn't actually running, and that if you need it for anything you'll need to go start it.  The tapas project should be accessible from your machine's browser at localhost:8080.

Then see http://github.com/NEU-DSG/tapas/wiki/Running-tapas,-tapas-rails,-and-eXist-in-the-development-environment

## Hungry for more TAPAS?
[TAPAS website](http://www.tapasproject.org/)

[TAPAS public documents, documentation, and meeting notes on GitHub](https://github.com/NEU-DSG/tapas-docs)

[TAPAS webapp (Drupal) on GitHub](https://github.com/NEU-DSG/tapas)

[TAPAS Hydra Head on GitHub](https://github.com/NEU-DSG/tapas_rails)

[TAPAS virtual machine provisioning on GitHub](https://github.com/NEU-DSG/plattr)
