cd /usr/src/
git clone https://github.com/kjhenner/puppetlabs-training-bootstrap -b nginx
cd /usr/src/puppetlabs-training-bootstrap/

sudo rake learning

#Disable update for pre-release build
#rm -rf /root/.testing
#/root/bin/quest update
