sudo apt update
sudo apt dist-upgrade
sudo reboot

sudo apt install libcurl4-openssl-dev git libreadline6-dev libssl-dev libyaml-dev libxml2-dev libxslt-dev autoconf ncurses-dev automake libtool bison

wget https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.1.tar.gz
tar xzf ruby-3.2.1.tar.gz
ruby-3.2.1/
./configure --prefix=/usr/local --enable-shared --disable-install-doc
make -j 2
sudo make install

curl https://my.webhookrelay.com/webhookrelay/downloads/install-cli.sh | bash
vi relay_config.yml
```
version: "v1"
key: KEY_HERE
secret: SECRET_HERE
buckets:
  - Buildlight
```
sudo relay service install -c /home/pi/relay_config.yml --user pi
sudo relay service start

mkdir app
copy config.ru Gemfile Gemfile.lock
bundle config set --local path 'vendor'
bundle install

# Setup puma to load via systemd
https://github.com/puma/puma/blob/master/docs/systemd.md

Change:
```
User=pi
WorkingDirectory=/home/pi/app
ExecStart=/usr/local/bin/bundle exec puma -p 8080 -v --redirect-stdout /home/pi/app/server.log
```

