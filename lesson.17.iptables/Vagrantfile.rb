# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "centos/7"

  # config.vm.provision "ansible" do |ansible|
  #   ansible.verbose = "vvv"
  #   ansible.playbook = "provisioning/playbook.yml"
  #   ansible.become = "true"
  # end


  config.vm.provider "virtualbox" do |v|
	  v.memory = 256
  end

  config.vm.define "inetRouter" do |inetRouter|
    inetRouter.vm.network "private_network", ip: "192.168.255.1", virtualbox__intnet: "iptab"
    inetRouter.vm.hostname = "inetRouter"
    inetRouter.vm.provision "shell", inline: <<-SHELL
    mkdir -p ~root/.ssh; cp ~vagrant/.ssh/auth* ~root/.ssh
    sed -i '65s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    systemctl restart sshd
    echo 'net.ipv4.conf.all.forwarding=1' >> /etc/sysctl.conf
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    sysctl -p
    cp /vagrant/nux-dextop.repo /etc/yum.repos.d/nux-dextop.repo
    yum install knock-server -y
    rm -rf /etc/knockd.conf
    cp /vagrant/knockd.conf /etc/knockd.conf
    echo 'OPTIONS="-i eth1"' > /etc/sysconfig/knockd
    chkconfig knockd on
    service knockd start
    iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
	echo "192.168.0.0/16 via 192.168.255.1" >  /etc/sysconfig/network-scripts/route-eth1
    service network restart
  SHELL
  end

  config.vm.define "inetRouter2" do |inetRouter2|
    inetRouter2.vm.network "private_network", ip: "192.168.255.2", virtualbox__intnet: "iptab"
    inetRouter2.vm.hostname = "inetRouter2"
    inetRouter2.vm.provision "shell", inline: <<-SHELL
  mkdir -p ~root/.ssh; cp ~vagrant/.ssh/auth* ~root/.ssh
  sed -i '65s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  systemctl restart sshd
  echo 'net.ipv4.conf.all.forwarding=1' >> /etc/sysctl.conf
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  sysctl --system
  iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
  echo "192.168.0.0/16 via 192.168.255.2" >  /etc/sysconfig/network-scripts/route-eth1
  systemctl restart network
  iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.255.3:80
  iptables -t nat -A POSTROUTING -o eth1 -p tcp --dport 80 -j SNAT --to-source 192.168.255.2
  iptables -A FORWARD -i eth1 -p tcp  -m conntrack --ctstate NEW -d 192.168.255.3 --dport 80  -j ACCEPT
  iptables -A INPUT -p TCP -j ACCEPT
  SHELL
end

  config.vm.define "centralServer" do |centralServer|
    centralServer.vm.network "private_network", ip: "192.168.255.3", virtualbox__intnet: "iptab"
    centralServer.vm.hostname = "centralServer"
    centralServer.vm.provision "shell", inline: <<-SHELL
  mkdir -p ~root/.ssh; cp ~vagrant/.ssh/auth* ~root/.ssh
  sed -i '65s/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
  systemctl restart sshd
  echo "DEFROUTE=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0 
  echo "GATEWAY=192.168.255.1" >> /etc/sysconfig/network-scripts/ifcfg-eth1
  systemctl restart network
  yum install epel-release -y
  yum install nginx -y
  service nginx start
SHELL
end
end
