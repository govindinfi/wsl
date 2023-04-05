#!/bin/bash
# ----------------------------------------------------------------
# Govind Kumar 
# Set the GRUB2 password 
# ----------------------------------------------------------------
set physical
echo "Setting GRUB2 password..."
grub2-mkpasswd-pbkdf2 | tee /tmp/grub.pbkdf2.sha512
echo "set superusers=\"root\"" >> /etc/grub.d/40_custom
echo "password_pbkdf2 root $(cat /tmp/grub.pbkdf2.sha512 | tail -n 1)" >> /etc/grub.d/40_custom
grub2-mkconfig -o /boot/grub2/grub.cfg   # Update the GRUB configuration
