# Main setup
## Install dependecies:
```shell
apt-get update 
apt-get upgrade -y
apt-get install -y python3.9 python3.9-dev python3.9-venv python3-pip libffi-dev libssl-dev libjpeg-dev zlib1g-dev autoconf build-essential libopenjp2-7 libtiff5 libturbojpeg0-dev libturbojpeg tzdata ssmtp
```

## Create System User
```shell
useradd -r -M -d /srv/homeassistant -s /bin/bash homeassistant
sudo mkdir /srv/homeassistant
sudo chown homeassistant:homeassistant /srv/homeassistant
```

## Install Home-Assistant
```shell
cd /srv/homeassistant
su homeassistant
python3.9 -m venv .
source bin/activate
pip install homeassistant
exit
```
## Setup System Service
```shell
nano /etc/systemd/system/home-assistant.service
```

```
[Unit]
Description=Home Assistant
After=network-online.target
[Service]
Type=simple
User=homeassistant
WorkingDirectory=/srv/homeassistant/.homeassistant
ExecStart=/srv/homeassistant/bin/hass -c "/srv/homeassistant/.homeassistant"
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

## Activate service
```shell
systemctl --system daemon-reload
systemctl enable home-assistant
systemctl start home-assistant
systemctl status home-assistant
```

# Optional
## Setup Auto update:

### Check if updates available:
```shell
nano /srv/homeassistant/check-for-updates.sh 
```

```shell
#!/bin/bash

source /srv/homeassistant/bin/activate

if [ `grep -c homeassistant <<< $(pip list --outdated --format freeze)` -ge 1 ]; then
  echo 1
else
  echo 0
fi

exit 0
```

```shell
chmod +x /srv/homeassistant/update-check.sh
/srv/homeassistant/update-check.sh
chown homeassistant:homeassistant /srv/homeassistant/update-check.sh
```

### Upgrade script:
```shell
nano /srv/homeassistant/upgrade-home-assistant.sh
```

```shell
#!/bin/bash

source /srv/homeassistant/bin/activate
pip3 install --upgrade homeassistant

exit 0
```

```shell
chown homeassistant:homeassistant /srv/homeassistant/upgrade-home-assistant.sh
chmod +x /srv/homeassistant/upgrade-home-assistant.sh
```

### Setup mailer:
```shell
nano /etc/ssmtp/ssmtp.conf
```

```shell
UseSTARTTLS=YES
FromLineOverride=YES
root=Admin@Home-Assistant.com
mailhub=smtp.gmail.com:587
AuthUser=your-mail-adress@gmail.com
AuthPass=YOUR-PASSWORD!
```

* If your Gmail account is secured with two-factor authentication, you need to generate a unique App Password to use in ssmtp.conf. You can do so on your App Passwords page. Use you Gmail username (not the App Name) in the AuthUser line and use the generated 16-character password in the AuthPass line, spaces in the password can be omitted.

* If you do not use two-factor authentication, you need to allow access to unsecure apps. You can do so on your Less Secure Apps page.

(Source: https://wiki.archlinux.org/title/SSMTP#Forward_to_a_Gmail_mail_server)

### Setup cronjob:

```shell
nano home-assistant-updater.cron
```

```shell
#!/bin/bash
echo "Starting updater $(date)"
if systemctl is-active --quiet home-assistant.service; then
  if [ $(su -c '/srv/homeassistant/check-for-updates.sh' homeassistant) -ne 0 ]; then
    echo "Stoping service"
    systemctl stop home-assistant.service
    echo "Backing up config"
    mkdir -p /srv/homeassistant/backups
    tar -czf "/srv/homeassistant/backups/Home-Assistant-config-$(date -u -I).tar.gz" -C /srv/homeassistant/ .homeassistant
    echo "Starting upgrade"
    su -c '/srv/homeassistant/upgrade-home-assistant.sh' homeassistant
    echo "Starting service"
    systemctl start home-assistant.service
    echo "Checking service"
    sleep 5
    if systemctl is-active --quiet home-assistant.service; then
      if [ $(ls /srv/homeassistant/backups | wc -l) -ge 5 ]; then
        echo "Deleting old backups"
        echo "removing $(ls -t /srv/homeassistant/backups/Home-Assistant-config-*.tar.gz | tail -1)"
        rm "$(ls -t /srv/homeassistant/backups/Home-Assistant-config-*.tar.gz | tail -1)"
      fi
      if [ $(ls /var/log/home-assistant-update/ | wc -l) -ge 4 ]; then
        echo "Deleting old logs"
        echo "removing $(ls -t /var/log/home-assistant-update/*.log | tail -1)"
        rm "$(ls -t /var/log/home-assistant-update/*.log | tail -1)"
      fi
      sendmail nils.stein@mailbox.org <<< "Subject: Home Assistant Update successful" <<<  "Home Assistant is now up-to-date"
      echo "Update successful"
    else
      sendmail nils.stein@mailbox.org <<< "Subject: Home Assistant Update FAILED" <<<  "Home Assistant is broken!"
      echo "FAILURE! Service is not comming up!"
      exit 1
    fi
  else
    echo "Home Assistant is up-to-date"
  fi
else
  echo "FAILURE! Service is not running!"
  exit 1
fi
echo ""
exit 0
```

```shell
crontab -e
```

```
  0 4    *   *   6   /root/home-assistant-updater.cron 2>&1 >> "/var/log/home-assistant-update/$(date -u -I).log"
```
