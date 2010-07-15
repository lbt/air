#!/bin/bash

pkg=$(dpkg-parsechangelog -ldebian/changelog | grep Source | cut -f2 -d' ')
ver=$(dpkg-parsechangelog -ldebian/changelog | grep Version | cut -f2 -d' ')
tag=v$ver

git archive $tag --format=tar --prefix ${pkg}-${ver}/ | gzip > ../${pkg}_${ver}.orig.tar.gz
dpkg-buildpackage -rfakeroot -S -uc -us -I -i -sA
