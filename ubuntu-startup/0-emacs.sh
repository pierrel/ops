#!/bin/bash

# emacs 27
sudo add-apt-repository ppa:kelleyk/emacs
sudo apt update
sudo apt install emacs27

# spacemacs
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d

# spacemacs config
cd ~
mkdir -p src
cd src
git clone https://github.com/pierrel/emacs.git
ln -s ~/src/emacs/.spacemacs ~/.spacemacs
