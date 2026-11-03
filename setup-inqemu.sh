sudo mkfs.ext4 /dev/vda
sudo mount /dev/vda /mnt
sudo chmod 777 -R /mnt

mv ~/.cache /mnt/.cache
mv ~/.config /mnt/.config

ln -s /mnt/.cache ~/.cache
ln -s /mnt/.config ~/.config

sudo apt update
sudo apt install git wget

cd /mnt
wget -qO code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
sudo apt-get install -y ./code.deb
code --install-extension GitHub.vscode-codeql


