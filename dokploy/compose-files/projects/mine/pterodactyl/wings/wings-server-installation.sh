
##Ensure folder

#sudo rm -r ./**
#sudo rm  /etc/pterodactyl/config.yml
 #sudo rm -r /etc/letsencrypt/*


echo Creating folder "~/server-data/games/wings"
sudo mkdir -p ~/server-data/games/wings
cd ~/server-data/games/wings

sudo rm -r ./**
sudo rm  /etc/pterodactyl/config.yml
sudo rm -r /etc/letsencrypt/*


git clone --filter=blob:none --no-checkout git@github.com:Cpinto0594/proxmox_scripts_tests.git
cd proxmox_scripts_tests
git sparse-checkout init --no-cone
git sparse-checkout set 'dokploy/compose-files/projects/mine/pterodactyl/**'
git checkout main
sudo mv dokploy/compose-files/projects/mine/pterodactyl/wings/* ../
cd ..
sudo rm -r proxmox_scripts_tests

sudo cp cloudflare.ini.example cloudflare.ini
sudo chmod 600 cloudflare.ini
sudo nano  cloudflare.ini

docker compose -f wings-compose.yml up -d --build

sudo nano /etc/pterodactyl/config.yml #config from the pterodactyl panel, not the wings

#after config pasted restart the deployment 
#docker compose -f wings-compose.yml up -d --force-recreate