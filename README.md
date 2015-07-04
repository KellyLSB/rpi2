# net6501 Toolchain Debian Sid

This toolchain is used to create a Debian Sid Soekris net6501 boot image.

## Dependencies

Dependencies are listed at http://github.com/KellyLSB/mkdebdisk.img

## Usage

    $ git clone git://github.com/KellyLSB/mkdebdisk.img-soekris-net6501.git
    $ cd mkdebdisk.img-soekris-net6501
    $ git submodule update --checkout --init
    $ ./build.sh
