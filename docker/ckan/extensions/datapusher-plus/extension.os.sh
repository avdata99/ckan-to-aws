#!/bin/bash -e

apt install -y file libuchardet-dev uchardet unzip wget

# file: for QSV
# wget: to get qsv
# unzip: for qsv
# locales: for locale settings qsv
# libuchardet-dev uchardet: for qsv

# Install QSV, requires root
# https://github.com/jqnatividad/qsv
echo "Installing QSV for Datapusher+"
wget https://github.com/jqnatividad/qsv/releases/download/0.134.0/qsv-0.134.0-x86_64-unknown-linux-gnu.zip
unzip qsv-0.134.0-x86_64-unknown-linux-gnu.zip
rm qsv-0.134.0-x86_64-unknown-linux-gnu.zip
mv qsv* /usr/local/bin

# Datapusher+ fails with locale.Error: unsupported locale setting
# I'm taking this piece of code from ckan/ckan-docker-base
# https://github.com/ckan/ckan-docker-base/blob/a02b410629ec8abd742cbe2539e1d37f6fb678ff/ckan-master/base/Dockerfile#L26-L34

# export LC_ALL=es_AR.UTF-8
export LC_ALL=en_US.UTF-8
apt-get -qq install --no-install-recommends -y locales

# Set the locale
sed -i "/$LC_ALL/s/^# //g" /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=${LC_ALL}
