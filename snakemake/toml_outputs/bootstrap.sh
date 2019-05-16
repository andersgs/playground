#/usr/bin/env bash

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
sh Miniconda3-latest-Linux-x86_64.sh -b -p /home/vagrant/miniconda3
rm Miniconda3-latest-Linux-x86_64.sh
echo "export PATH=/home/vagrant/miniconda3/bin:$PATH" > /home/vagrant/.bashrc
export PATH=/home/vagrant/miniconda3/bin:$PATH
pip install cython
pip install git+https://github.com/pytries/datrie.git
pip install snakemake

