#!/bin/bash

# Nom			: post-installation.BookStack.sh
# Description	: Script d'installation et de configuration de la base de connaissance BookStack
# Auteurs		: Joakim PETTERSEN, Léo PEROCHON, Arthur DUPUIS
# Version		: 1.1

if [ "$EUID" -ne 0 ]
    then echo "Please run it as root"
    exit
fi

echo '##################################################'
echo '#      Installation des dependances               #'
echo '##################################################'
echo ' '
apt update
apt install nginx -y | tee ~/install_bookstack.log
apt install php-fpm php-mysql php-dom php-curl php-gd php-xml php-tokenizer php-mbstring -y | tee -a ~/install_bookstack.log
apt install mariadb-server -y | tee -a ~/install_bookstack.log
apt install composer -y | tee ~/install_bookstack.log
apt install git -y | tee ~/install_bookstack.log

echo '##################################################'
echo '#            Configuration MariaDB               #'
echo '##################################################'
echo ' '
mariadb -e "DROP DATABASE IF EXISTS bookstack;"
mariadb -e "DROP USER IF EXISTS 'bookstack'@'localhost';"
mariadb -e "CREATE DATABASE bookstack;"
mariadb -e "CREATE USER bookstack identified by 'password';"
mariadb -e "GRANT ALL PRIVILEGES on bookstack.* TO 'bookstack'@'localhost' identified by 'bookstack';"
mariadb -e "FLUSH PRIVILEGES;"

echo '##################################################'
echo '#            Clonage Git Bookstack               #'
echo '##################################################'
echo ' '
cd /var/www/
git clone https://github.com/BookStackApp/BookStack.git --branch release --single-branch
mv /var/www/BookStack/ /var/www/bookstack/

echo '##################################################'
echo '#        Droit user sur les fichiers             #'
echo '##################################################'
echo ' '
cd /var/www/bookstack/
chown -R www-data. storage/
chown -R www-data. public/uploads
chown -R www-data. bootstrap/cache
cd /var/www/bookstack/
echo "yes\n" | composer install --no-dev

echo '##################################################'
echo '#         Modification env Bookstack             #'
echo '##################################################'
echo ' '
cp /var/www/bookstack/.env.example /var/www/bookstack/.env
sed -i 's;APP_URL=https://example.com;APP_URL=http://wiki.test.local;' .env
sed -i 's;DB_DATABASE=database_database;DB_DATABASE=bookstack;' .env
sed -i 's;DB_USERNAME=database_username;DB_USERNAME=bookstack;' .env
sed -i 's;DB_PASSWORD=database_user_password;DB_PASSWORD=bookstack;' .env

echo '##################################################'
echo '#                 PHP Artisan                    #'
echo '##################################################'
echo ' '
cd /var/www/bookstack/
echo -e "yes\n" | php artisan key:generate --force
echo -e "yes\n" | php artisan migrate --force

echo '##################################################'
echo '#         Config serveur Bookstack               #'
echo '##################################################'
echo ' '
cat > /etc/nginx/sites-available/bookstack.conf << 'EOF'
server {
        listen 80;
        server_name wiki.test.local;

        root /var/www/bookstack/public;
        index index.php index.html;

        location / {
                try_files $uri $uri/ /index.php?query_string;
        }

        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        }
}
EOF
ln -s /etc/nginx/sites-available/bookstack.conf /etc/nginx/sites-enabled/bookstack.conf
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

echo '##################################################'
echo '#                   RESTART                      #'
echo '##################################################'
echo ' '
nginx -t 
systemctl restart nginx
