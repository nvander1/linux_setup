#!/bin/bash
# Sets up a fresh Fedora installation.
# Author: Nik Vanderhoof

# User Info
USER_FULL_NAME="Nik Vanderhoof"
USER_EMAIL="nikolasrvanderhoof@gmail.com"
USER_GITHUB_PROFILE="nvander1"
USER_CONFIG_REPO="config"
USER_GIT_FOLDER="$HOME/Github"

USER_CONFIG_FOLDER=$USER_GIT_FOLDER/$USER_GITHUB_PROFILE/$USER_CONFIG_REPO
TEMP_DIR="/tmp/initial_fedora_setup"
TEMP_PUBLIC_KEYS=$TEMP_DIR/public_keys

echo "Creating tmp directory..."
mkdir -p $TEMP_DIR

echo "Downloading RPMs..."
wget https://dbeaver.io/files/dbeaver-ce-latest-stable.x86_64.rpm -O $TEMP_DIR/dbeaver.rpm
wget https://downloads.slack-edge.com/linux_releases/slack-3.4.2-0.1.fc21.x86_64.rpm -O $TEMP_DIR/slack.rpm

echo "Installing packages..."
sudo dnf install git sbt neovim zsh docker $TEMP_DIR/dbeaver.rpm $TEMP_DIR/slack.rpm

echo "Configuring docker..."
sudo systemctl start docker.service
sudo systemctl enable docker.service

echo "Generating an SSH key..."
ssh-keygen -t rsa -b 4096 -C $USER_EMAIL
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

echo "# SSH Key" >> $TEMP_PUBLIC_KEYS
cat ~/.ssh/id_rsa.pub >> $TEMP_PUBLIC_KEYS
echo >> $TEMP_PUBLIC_KEYS

echo "Generating a GPG key..."
cat > $TEMP_DIR/gpg_config <<EOF
    %echo Generating a gpg key for this machine.
    Key-Type: RSA
    Key-Length: 4096
    Subkey-Type: default
    Name-Real: $USER_FULL_NAME
    Name-Email: $USER_EMAIL
    Expire-Date: 1y
    %commit
    %echo Key generation complete.
EOF
gpg --batch --generate-key $TEMP_DIR/gpg_config
rm $TEMP_DIR/gpg_config
echo "# GPG Key" >> $TEMP_PUBLIC_KEYS
gpg --armor --export $EMAIL >> $TEMP_PUBLIC_KEYS
echo >> $TEMP_PUBLIC_KEYS

echo "Configuring git..."
git config --global user.name $USER_FULL_NAME
git config --global user.email $USER_EMAIL
git config --global user.signingkey `gpg --list-keys | head -n 4 | tail -n 1 | sed -e 's/^[[:space:]]*//'`
git config --global commit.gpgsign true
git config --global gpg.program gpg2

cat $TEMP_PUBLIC_KEYS
read -n 1 -s -r -p "Add the ssh and gpg key to your github account."
echo

echo "Cloning dotfiles repo..."
mkdir -p $USER_GIT_FOLDER/$USER_GITHUB_PROFILE
git clone git@github.com:$USER_GITHUB_PROFILE/$USER_CONFIG_REPO.git $USER_CONFIG_FOLDER

echo "Configuring neovim"
[ -e ~/.config/nvim] && rm -rf ~/.config/nvim
mkdir -p ~/.config/nvim
ln -s $USER_CONFIG_FOLDER/init.vim ~/.config/nvim/init.vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
nvim +PlugInstall +qall > /dev/null

echo "Configuring zsh..."
chsh -s "/bin/zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
[ -e ~/.zshrc ] && rm ~/.zshrc
ln -s $USER_CONFIG_FOLDER/zshrc ~/.zshrc

echo "Configuring tmux..."
[ -e ~/.tmux.conf ] && rm ~/.tmux.conf
ln -s $USER_CONFIG_FOLDER/tmux.conf ~/.tmux.conf


echo "Removing tmp directory..."
rm -rf $TEMP_DIR
