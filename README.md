Housewarming
============
Tired of reconfiguring your new bare metal or VM? How about a simple bash script to take the pain away?

```bash
curl -L https://raw.githubusercontent.com/imacks/housewarm/master/src/ubuntu-18.04.sh -o /tmp/housewarm.sh
sed -i 's/#PKG_POWERSHELL_URL=/PKG_POWERSHELL_URL=/g' /tmp/housewarm.sh
sed -i 's/AUTO_REBOOT="true"/AUTO_REBOOT="false"/g' /tmp/housewarm.sh
chmod +x /tmp/housewarm.sh
sudo /tmp/housewarm.sh | tee /tmp/housewarm.log
```
