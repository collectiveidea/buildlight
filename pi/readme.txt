Load Raspberry Pi OS Lite (64 bit)

sudo apt update
sudo apt dist-upgrade
sudo reboot

sudo apt install libcurl4-openssl-dev git libreadline6-dev libssl-dev libyaml-dev libxml2-dev libxslt-dev autoconf ncurses-dev automake libtool bison

wget https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.1.tar.gz
tar xzf ruby-3.2.1.tar.gz
cd ruby-3.2.1/
./configure --prefix=/usr/local --enable-shared --disable-install-doc
make -j 2
sudo make install

mkdir listener
copy listener.rb Gemfile Gemfile.lock
chmod +x listener.rb
bundle config set --local path 'vendor'
bundle install

# Setup listener to load via systemd
copy buildlight_listener.service to /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable buildlight_listener.service
sudo systemctl start buildlight_listener.service
