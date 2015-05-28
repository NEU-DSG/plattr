Plattr
=======

Isn't fancy or interesting or even really a proper project.  It's just a Vagrant config that can/should allow everyone associated with TAPAS development to work from a preconfigured box.  Currently a work in progress.

## Installation Instructions 

1. Ensure that you have a relatively modern [Vagrant](http://www.vagrantup.com/) installation on your machine.  Downloads are [here](https://www.vagrantup.com/downloads.html).  I, @jbuckle, am running Vagrant 1.5.0.  The latest is 1.6.5, which I imagine (haven't actually checked) ought to work. 
    * For a significant speed increase during vagrant creation, install the vagrant-cachier plugin.  Documentation [here](https://github.com/fgrehm/vagrant-cachier).  The command is ``vagrant plugin install vagrant-cachier``
2. Clone the repository down: ``git clone https://github.com/NEU-DSG/plattr.git``
3. Ensure that within the plattr directory, you create a requirements/local directory 
3. Clone the tapas_rails repository down: ``git clone https://github.com/neu-libraries/tapas_rails.git``
    * For a significant speed increase during vagrant up, run ``bundle package`` from inside the tapas_rails directory.  This will cache the gems specified by the project Gemfile into vendor/cache and eliminate the need to dl them from inside your Vagrant box.  Note that you need to have ruby installed and the bundler gem available for this to do anything.
4.  There is one file not in VC that is required for the project to run.  Ask me (@jbuckle) for the application.yml file and then place it at ~/tapas_rails/config/
5. CD into the root directory of the project and run ``vagrant up``.  Be patient - installation takes time. 
6. Type ``vagrant ssh`` and you should be ssh'd directly into the machine.  Since none of the components talk to each other (yet) this is everything you need to do.  Do note that the Rails server isn't actually running, and that if you need it for anything you'll need to go start it.  The tapas project should be accessible from your machine's browser at localhost:8080.

Then see http://github.com/NEU-DSG/tapas/wiki/Running-tapas,-tapas-rails,-and-eXist-in-the-development-environment

## Hungry for more TAPAS?
[TAPAS website](http://www.tapasproject.org/)

[TAPAS public documents, documentation, and meeting notes on GitHub](https://github.com/NEU-DSG/tapas-docs)

[TAPAS webapp (Drupal) on GitHub](https://github.com/NEU-DSG/tapas)

[TAPAS Hydra Head on GitHub](https://github.com/NEU-DSG/tapas_rails)

[TAPAS virtual machine provisioning on GitHub](https://github.com/NEU-DSG/plattr)
