# RPI2 Toolchain Debian Jessie

This toolchain is used to create a Debian Jessie Raspberry Pi 2 boot image.

Thank you [Petter Reinholdtsen](http://people.skolelinux.org/pere/) for his article on building RPi2 images with vmdebootstrap. [Click for Article](http://people.skolelinux.org/pere/blog/Teaching_vmdebootstrap_to_create_Raspberry_Pi_SD_card_images.html)

I have extended upon the basis of his work and created a wrapper script that prepares the `customize` script. This includes support for using Apt-Cacher-NG in the build process. Saving soooo much time and energy.

It's not complicated; just convenient and easy to dynamically customize.

## Dependencies

This toolchain has the following dependencies (note: I am running Debian Jessie).

    $ sudo apt-get install -y \
        vmdebootstrap \
        qemu-arm-static \
        realpath \
        devmapper \
        kpartx
