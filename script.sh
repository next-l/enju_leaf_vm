echo "start sciprt."
# enju_leafの動作環境。developmentかproductionを指定
ENJU_ENV=production
 
# enju_leaf-1.1系の場合
RAILS_VERSION=3.2.19
TEMPLATE_URL=https://gist.github.com/nabeta/5357321.txt
 
# enju_leaf-1.2系の場合
#RAILS_VERSION=4.1.4
#TEMPLATE_URL=https://gist.github.com/nabeta/6319160.txt
 
USER=vagrant
 
echo "change repository"
sed -i -e 's/archive.ubuntu.com/jp.archive.ubuntu.com/g' /etc/apt/sources.list
 
echo "step1 : package update and install"
apt-get -y install software-properties-common
add-apt-repository -y ppa:brightbox/ruby-ng
apt-get update 
apt-get -y upgrade
apt-get -y install ruby2.1-dev
apt-get -y install git w3m vim
apt-get -y install build-essential imagemagick openjdk-7-jre-headless
apt-get -y install zlib1g-dev
apt-get -y install memcached nodejs redis-server
apt-get -y install libicu-dev libxslt1-dev
apt-get -y install libsqlite3-dev
#apt-get -y install postgresql libpq-dev
#apt-get -y install mysql-server libmysqlclient-dev
#apt-get -y install tomcat7 tomcat7-admin
apt-get -y install nginx-full
 
echo "step2 : install rails"
gem install rails --version=$RAILS_VERSION --no-ri --no-rdoc --force
gem install whenever foreman --no-ri --no-rdoc
 
echo "step3 : install enju_leaf"
sudo su $USER -c "rails _${RAILS_VERSION}_ new enju -m ${TEMPLATE_URL} -d sqlite3 --skip-bundle"
cd enju
sed -i -e "s/# gem 'unicorn'/gem 'unicorn'/g" Gemfile
sudo su $USER -c 'echo "gem: --no-ri --no-rdoc" >> ${HOME}/.gemrc'
sudo su $USER -c 'bundle -j4 --path vendor/bundle'
 
echo "step4 : setup enju_leaf"
sudo su $USER -c 'rails g enju_leaf:setup'
sudo su $USER -c "ENJU_ENV=${ENJU_ENV} rails g enju_leaf:quick_install"
sudo su $USER -c 'whenever --update-crontab'
sudo su $USER -c "echo 'solr: bundle exec rake sunspot:solr:run RAILS_ENV=${ENJU_ENV}
resque: bundle exec rake environment resque:work QUEUE=* RAILS_ENV=${ENJU_ENV}
web: bundle exec unicorn -E ${ENJU_ENV}' > Procfile"
#sed -i -e 's/config.serve_static_assets = true/config.serve_static_assets = false/g' config/environments/production.rb

mkdir /var/log/enju_leaf
chown vagrant /var/log/enju_leaf
foreman export --app enju_leaf --user $USER upstart /etc/init/
 
echo "step5 : setup web server"
cat <<EOL > /etc/nginx/sites-available/enju_leaf
server{
  gzip on;
  location / {
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_pass http://localhost:8080;
  }
}
EOL
 
rm /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/enju_leaf /etc/nginx/sites-enabled/enju_leaf
 
#cp /etc/rc.local /etc/rc.local.orig
#cp /etc/issue /etc/issue.orig
#cat <<EOL > /etc/rc.local
#IP_ADDR=\$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print \$1}')
#echo "Next-L Enju Leaf is running at http://\${IP_ADDR}" > /etc/issue
#echo "Make sure that you set up a bridged network if you are using VirtualBox." >> /etc/issue
#EOL
 
echo "step6 : cleaning"
apt-get autoremove --purge -y
apt-get clean
 
# Removing leftover leases and persistent rules
#rm /var/lib/dhcp/*
 
# Zero free space to aid VM compression
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
 
#echo "step7 : starting enju_leaf"
#start enju_leaf
#/etc/init.d/nginx restart
 
echo "setup completed."
