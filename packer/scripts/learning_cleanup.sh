export PATH=$PATH:/opt/puppetlabs/bin/

# Install docker module
puppet module install garethr-docker --modulepath=/etc/puppetlabs/code/modules

# Run puppet twice
puppet agent -t

puppet agent -t

# Stop all PE processes to free up memory
for s in `find /etc/init.d/ -name pe* -type f -printf "%f\n"`
do
  service $s stop
done

# Clean up PE installer files
rm -rf /root/puppet-enterprise*
rm -rf /root/puppet-enterprise
rm -rf /usr/src/installer


# Clean up other random files
rm -rf /usr/src/puppetlabs-training-bootstrap
rm -rf /usr/src/puppet
rm -rf /usr/src/kernels
rm -rf /var/cache/yum
rm -rf /opt/puppet/share/ri
rm -rf /home/vagrant/linux.iso
rm -rf /training

yum clean all

# Prevent VirtualBox CPU issue by disabling APIC
sed -e 's/\tkernel.*/& noapic/' /boot/grub/grub.conf > /tmp/new_grub.conf
mv /boot/grub/grub.conf /boot/grub/grub.conf.bak
mv /tmp/new_grub.conf /boot/grub/grub.conf
