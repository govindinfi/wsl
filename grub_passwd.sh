#!/bin/bash
# ----------------------------------------------------------------
# Govind Kumar 
# Set the GRUB2 password 
# ----------------------------------------------------------------
echo "Setting GRUB2 password..."
grub2-mkpasswd-pbkdf2 | tee /etc/grub2/grub.pbkdf2.sha512 > /dev/null
echo "set superusers=\"root\"" >> /etc/grub2.cfg
echo "password_pbkdf2 root $(cat /etc/grub2/grub.pbkdf2.sha512)" >> /etc/grub2.cfg
echo "Done."
