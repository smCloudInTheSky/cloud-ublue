# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'
FQDN_DOMAIN = "lan"
Vagrant.configure("2") do |config|
  # Libvirt-compatible base box (Ubuntu 24.04)
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  BOX = "cloud-image/ubuntu-24.04"
  BOX_VERSION = "20250805.0.0"

  # Set your host bridge/NIC for the bridged interface (examples: "br0", "eno1", "enp3s0")
  # You can also export BRIDGE_DEV=br0 before running `vagrant up`.
  BRIDGE_DEV = `ip route | awk '/^default/ {printf "%s", $5; exit 0}'`
  # BRIDGE_DEV = ENV["BRIDGE_DEV"] # leave nil to let Vagrant/libvirt try defaults

  # Common isolated network (shared by all VMs). This is an isolated libvirt network
  # (no forwarding to the outside world). Host can still reach it via the libvirt bridge.
  ISOLATED = {
    name:         "vagrant-isolated",
    address:      "192.168.56.0",
    mask:         "255.255.255.0",
    domain:       "isolated.local",
    forward_mode: "none",    # no NAT/route
  }

  # Disable default synced folder for cleanliness (optional).
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provision "file", source: "~/.ssh/sesterce.pub", destination: "~/.ssh/sesterce.pub"
  config.vm.provision "shell", inline: <<-SHELL
    cat /home/vagrant/.ssh/sesterce.pub >> /home/vagrant/.ssh/authorized_keys
  SHELL
  # Define roles and ranges
  roles = {
    "postgres" => (1..3),
    "maas"     => (1..3),
    "compute"  => (1..3),
  }

  roles.each do |role, range|
    range.each do |i|
      name = "#{role}#{i}"

      # Assign static IPs on the isolated network per role
      isolated_ip =
        case role
        when "postgres" then "192.168.56.#{9 + i}"   # 192.168.56.10-12
        when "maas"     then "192.168.56.#{19 + i}"  # 192.168.56.20-22
        when "compute"  then "192.168.56.#{29 + i}"  # 192.168.56.30-32
        end


      config.hostmanager.enabled = true
      config.hostmanager.manage_host = true
      config.hostmanager.manage_guest = true
      config.hostmanager.ignore_private_ip = false
      config.hostmanager.include_offline = true

      config.vm.define name do |node|
        node.vm.box = BOX
        node.vm.box_version = BOX_VERSION
        node.vm.hostname = "#{name}.#{FQDN_DOMAIN}"

        # 1) Bridged network to your local LAN
        # For libvirt, prefer specifying your bridge/NIC: BRIDGE_DEV (e.g., "br0", "eno1").
        if BRIDGE_DEV && !BRIDGE_DEV.empty?
          node.vm.network "public_network", dev: "#{BRIDGE_DEV}" # or "eth0" or your appropriate network interface
        else
          # If not set, Vagrant/libvirt may try a default. If it fails,
          # set BRIDGE_DEV (e.g. export BRIDGE_DEV=br0) and re-run.
          node.vm.network "public_network"
        end

        ## 2) Isolated network shared by all VMs (no forwarding)
        #node.vm.network "private_network",
        #  ip: isolated_ip,
        #  libvirt__network_name:    ISOLATED[:name],
        #  libvirt__forward_mode:    ISOLATED[:forward_mode],
        #  libvirt__network_address: ISOLATED[:address],
        #  libvirt__network_mask:    ISOLATED[:mask],
        #  libvirt__dhcp_enabled:    false,
        #  libvirt__domain_name:     ISOLATED[:domain]

        # Libvirt provider settings
        node.vm.provider :libvirt do |lv|
          lv.cpus   = 2
          lv.memory = 2048
          # Enable nested virtualization if supported
          lv.nested = true if lv.respond_to?(:nested)
        end
      end

      config.vm.provision :hostmanager
    end
  end
end
