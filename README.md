# RPI2 Toolchain Debian Jessie

This toolchain is used to create a Debian Jessie Raspberry Pi 2 boot image.

## Dependencies

Dependencies are listed at http://github.com/KellyLSB/mkdebdisk.img

## Usage

    $ git clone git://github.com/KellyLSB/rpi2
    $ cd rpi2
    $ git submodule update --checkout --init
    $ ./build.sh
