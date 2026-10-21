Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # Script común de corrección para todas las VMs
  config.vm.provision "shell", path: "provisioning/fix-apt.sh"

  # Servidor Web
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.network "forwarded_port", guest: 80, host: 8080
    web.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    web.vm.provision "shell", path: "provisioning/web.sh"
  end

  # Servidor ERP (Backend API)
  config.vm.define "erp" do |erp|
    erp.vm.hostname = "erp"
    erp.vm.network "private_network", ip: "192.168.56.11"
    erp.vm.network "forwarded_port", guest: 3000, host: 3000
    erp.vm.provider "virtualbox" do |vb|
      vb.memory = 1536
      vb.cpus = 2
    end
    erp.vm.provision "shell", path: "provisioning/erp.sh"
  end

  # Servidor Base de Datos
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.12"
    db.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
    end
    db.vm.provision "shell", path: "provisioning/db.sh"
  end

  # Servidor de Archivos
  config.vm.define "files" do |files|
    files.vm.hostname = "files"
    files.vm.network "private_network", ip: "192.168.56.13"
    files.vm.network "forwarded_port", guest: 8081, host: 8081
    files.vm.provider "virtualbox" do |vb|
      vb.memory = 768
      vb.cpus = 1
    end
    files.vm.provision "shell", path: "provisioning/files.sh"
  end
end