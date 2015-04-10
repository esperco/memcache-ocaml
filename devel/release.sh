#!/bin/bash

# do not run

basedir=`dirname $0`
basedir=`readlink -f $basedir/../`
cd $basedir || exit 1

version=`head -n1 VERSION`
name=memcache-ocaml
tar=$name-$version.tar.gz
tar_dst=$HOME/htdocs/src/$name
doc_dst=$tar_dst
chroot_dir=/home/komar/chroot/squeeze-x86
chroot_dist_dir=/home/komar/memcache
user=komar

darcs dist -d $name-$version || exit 1
cp $tar $tar_dst || exit 1
make -s clean || exit 1
make -s doc || exit 1
cp -r doc $doc_dst || exit 1

