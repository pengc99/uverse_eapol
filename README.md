##### Overview
This document explains how to use a Ubiquiti Unifi Security Gateway Pro to bypass the AT&T Router Gateway (RG) device, authenticating directly with the DSLAM or with the ONT. These instructions will work whether you are using Uverse Fiber or Uverse VDSL. The only difference is if you are using Uverse Fiber, you don't need the DSL SFP module mentioned since you will be interfacing directly with the ONT over Ethernet. Both Fiber and VDSL service authenticate using EAPoL. 

This guide *will* work if you have any kind of additional service such as TV or phone, but you will no longer be able to receive TV and phone service. 

This guide *will not* work if you are using bonded VDSL service. You are using bonded VDSL service if your speeds are greater than 100mbit downstream. You can also check in the RG status page to see if the VDSL interface is in bonded mode. 

##### Background
AT&T Uverse service is a triple-play service (internet, phone, and TV) provided by AT&T - depending on what service is available in your area you may be getting FTTH (Fiber to the Home), FTTN (Fiber to the Node), or VDSL (either bonded or unbonded).

FTTN and VDSL both use VDSL2 connectivity from your house to the network. The advantage with FTTN over FTTH is reduced deployment costs for MDUs (Multiple Dwelling Units, such as condos or apartment complexes) - AT&T only has to run fiber to a local node that then serves VDSL2 to the customers.

The problem isn't the service, the problem is with the RG that AT&T provides. It's a decently powerful unit that allows for triple play services. However, there are a lot of limitations in the RG, namely the limitation of ~8000 NAT sessions, a poor interface with very limited options, and no true passthrough.

But wait! IP Passthrough? Why not just use that? The problem is **if you're using IP Passthrough, the RG still tracks all connections going through the RG**. Once you hit the connection limit of 8196 connections, which admittedly is more than most people need, the RG will refuse new connections. 

I've also had some instances where the RG will spontaneously reboot or crash and hang when under heavy usage. I needed to explore options on how to bypass the RG and use my own (hopefully more sane) DSL modem that doesn't do any connection tracking is just a pure layer 2 bridge between AT&T's VDSL network and my router. 

Why use a DSL SFP module, and not a regular consumer DSL modem? The reason for this is because every consumer DSL modem I've found uses PPPoE authentication, while Uverse uses EAPoL authentication. EAPoL authentication uses TLS based authentication with certificates, instead of a username and password. There are a few benefits to this, namely authentication is provided by certificates and not usernames and passwords, and also there is no need for MTU shifting.

There are also modems that claim to use be a "Bridge Modem", or a device that simply handles the DSL training, and then bridges the DSL interface to the Ethernet interface. However, EAPoL packets are not forwarded across bridges by design, and the handful of DSL "Bridge Modems" I've tried such as the Netgear DM200 or Zyxel VMG4500 do not forward EAPoL authentication packets.

The working solution I've been using is to use a SFP DSL module, which will plug into high-end consumer routers that have SFP ports or commercial \ industrial routers. I found a few companies selling DSL SFP modules and sent out a few emails asking for technical information; namely I was looking for modules that would pass EAPoL packets.

Of the companies I emailed, one replied with a slightly vague response (Versatek), one replied saying they were not interested in helping individuals (Proscend), and one responded almost immediately with actual helpful information (Netsys), stating that their modules will pass EAPoL packets. Hats off to Terry at Netsys for being so helpful and willing to answer technical questions!

In the end I ordered a Netsys 100SFP-S DSL SFP module for $99 and eagerly awaited it's arrival. You can find more information about their DSL SFP module here: https://www.netsys-direct.com/collections/dsl-products/products/long-reach-ethernet-over-vdsl2-sfp-cpe-slave-nv-100sfp-s

##### Hardware Needed 
* Netsys 100SFP-S VDSL SFP module
* AT&T Uverse Router / Gateway BGW210-700
* A router that is capable of setting VLANs on the WAN / Ethernet interface, and has an SFP port
  * I'm using a Ubiquiti Unifi Security Gateway Pro. Any prosumer or professional router should allow you to set the VLAN on the WAN interface, but I haven't seen this option in consumer Linksys / Netgear etc type routers. You may need to flash an alternative firmware like OpenWRT to get this if you have a consumer grade router. 
  * Additionally, if your router does not have an SFP port, you can also just build a device that bridges an SFP interface to an Ethernet interface, but that is left as an exercise for the reader. 

##### Software Needed 
* curl (already installed on recent Windows 10 builds)
* 7zip - https://www.7-zip.org/
* FileZilla - https://filezilla-project.org/
* PuTTY - https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
* mfg_dat_decode - https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
  * Your computer may detect malware and prevent you from downloading this file. If it makes you uncomfortable, you can run it in a VM and destroy the VM when you're done. 
* AT&T UVerse RG firmware archive - https://mega.nz/file/35lBkbzC#MTrKdt57SEuz81Tn3MBKm-o_s1zv643MLmxyKILjsk8

##### Dowonload Software and Prep
1. Download the software under the "Software Needed" section
2. Download the following files from the repo:
  ```
  uverse_eapol.sh
  wpa_supplicant-v2.7-hostap_2_7-1-g8f0af16.zip
  wpa_supplicant.conf
  ```
3. Log into your Unifi console and get the SSH password for the `admin` SSH user. Then change the WAN interface to use VLAN 0. After you submit the changes, the Unifi Security Gateway will drop offline. 
4. Maybe have some alternative method of getting to the internet in case something is borked up.

##### Extract Certificates From AT&T UVerse RG 
1. Unzip the AT&T RG Uverse firmware package - we're looking for `spTurquoise210-700_1.0.29.bin`
2. Disconnect the DSL cable from the RG. 
3. Log into your RG and downgrade the firmware with the above firmware file. The process takes several minutes and modem will reboot. 
4. After the RG is running again, go to http://192.168.1.254/cgi-bin/ipalloc.ha and assign yourself a static IP address
5. Refresh your computer's IP address to make sure you have the private IP address that was assigned.
6. Log into the RG again and authenticate
7. Run the following curl commands to start a telnet server on the RG. When prompted for the password for the user `tech`, just hit `ENTER`. After the last command is executed, the RG will reboot. 
  ```
  curl -k -u tech -H "User-Agent: blah" -H "Connection:Keep-Alive" -d "appid=001&set_data=| echo 28telnet stream tcp nowait root /usr/sbin/telnetd -i -l /bin/nsh > /var/etc/inetd.d/telnet28|" -v --http1.1 https://192.168.1.254:49955/caserver
  ```
  ```
  curl -k -u tech -H "User-Agent: blah" -H "Connection:Keep-Alive" -d "appid=001&set_data=| pfs -a /var/etc/inetd.d/telnet28|" -v --http1.1 https://192.168.1.254:49955/caserver
  ```
  ```
  curl -k -u tech -H "User-Agent: blah" -H "Connection:Keep-Alive" -d "appid=001&set_data=| pfs -s|" -v --http1.1 https://192.168.1.254:49955/caserver
  ```
  ```
  curl -k -u tech -H "User-Agent: blah" -H "Connection:Keep-Alive" -d "appid=001&set_data=| reboot|" -v --http1.1 https://192.168.1.254:49955/caserver
  ```
8. Log into the RG with PuTTY using the IP address 192.168.1.254 on port 28 using the Telnet selection
9. Remount `root` file system as writeable
  ```
  mount -o remount,rw /dev/ubi0 /
  ```
10. Mount the `mfg` partition which contains the certificates
  ```
  mount mtd:mfg -t jffs2 /mfg
  ```
11.  Copy the certificate bundle to the web server directory
  ```
  cp /mfg/mfg.dat /www/att/mfg.dat
  ```
12. Tar and copy the intermediate and root certificates to the web server directory
  ```
  tar -zcvf /www/att/certs.tar.gz /etc/rootcert/
  ```
13. Download the certificate bundle and the intermediate and root certificates:

    http://192.168.1.254/mfg.dat
    
    http://192.168.1.254/certs.tar.gz
14. Throw the RG into the garbage
    * Don't actually throw it in the garbage, you need to return it when you terminate your service with AT&T otherwise they will bill you a hefty sum.
    * Using the firmware archive that was downloaded earlier, you can step the RG back up to the current firmware by flashing 1.0.29, then 1.5.12, then 2.7.1
15. Extract the `mfg_dat_decode` utility that was downloaded earlier
16. Extract the `certs.tar.gz` archive that was downloaded earlier
17. Copy the `mfg.dat` file into the folder with the `mfg_dat_decode` binary
18. Copy all of the certificates extracted from `certs.tar.gz` into the folder with the `mfg_dat_decode` binary
19. Run the `mfg_dat_decode` binary, which will extract and create a tar.gz containing certificates and a `wpa_supplicant.conf` configuration file.
20. Extract the tar.gz file - you'll end up with a directory that contains three `pem` formatted certificates, a sample `wpa_supplicant.conf` file, and a `readme.txt` file. We only want to keep the three `pem` formatted certificates.
21. Don't forget to set your computer back to DHCP! 

##### wpa_supplicant Configuration and Files
1. Extract the `wpa_supplicant-v2.7-hostap_2_7-1-g8f0af16.zip` archive. This contains a recent git MIPS binary of `wpa_supplicant`
2. Edit the `wpa_supplicant.conf` file to have the correct names for the certificates you extracted from step 20 above. Leave the paths alone.
3. Edit `uverse_eapol.sh` to have the correct interface name for your DSL SFP interface. On my Unifi Security Gateway Pro, the first WAN SFP port is `eth2`
4. You will need to log into the Unifi Security Gateway directly via SSH (PuTTY) and SCP (FileZilla) for the next few steps.
5. Copy the files to the Unifi Security Gateway Pro to the following locations with SCP. Since you can only authenticate as `admin`, you may need to uplink them to `/home/admin` first, then log in with SSH and `sudo su` to root to be able to move the files to the final location.
  ```/config/scripts/wpa_supplicant
  /config/scripts/wpa_supplicant.conf
  /config/scripts/post-config.d/uverse_eapol.sh
  /config/auth/<your CA certificate file>
  /config/auth/<your client certificate file>
  /config/auth/<your private key>
  ```
6. Set some permissions
  ```
  sudo chmod +x /config/scripts/wpa_supplicant
  sudo chmod +x /config/scripts/post-config.d/uverse_eapol.sh
  sudo chmod -R 0600 /config/auth
  ```
7. Unplug the existing Ethernet cable from the WAN1 interface, and plug in the DSL SFP module into the WAN1 SFP port. Plug in your telephone line into the DSL SFP module.
8. On the right side of the DSL SFP module, there is a green light. When it is blinking, it is training the DSL interface. When it turns solid, the DSL interface is trained.
9. Run the following command to re-run the startup scripts, which will start `wpa_supplicant`. This needs to be run as `root` or with `sudo`.
  ```
  run-parts --report --regex '^[a-zA-Z0-9._-]+$' "/config/scripts/post-config.d"
  ```
10. You can check the log output to see if the interface authenticates
  ```
  tail -n 50 -f /var/log/messages
  ```
11. The specific lines we're looking for are these, which shows a sucessful EAPoL authentication
  ```
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-STARTED EAP authentication started
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-PROPOSED-METHOD vendor=0 method=13
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-METHOD EAP vendor 0 method 13 (TLS) selected
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-PEER-CERT depth=2 subject='/C=US/O=ATT Services Inc/CN=ATT Services Inc Root CA' hash=<hash>
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-PEER-CERT depth=1 subject='/C=US/O=ATT Services Inc/CN=ATT Services Inc Enhanced Services CA' hash=<hash>
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-PEER-CERT depth=0 subject='/C=US/ST=Michigan/L=Southfield/O=ATT Services Inc/OU=OCATS/CN=aut01rcsntx.rcsntx.sbcglobal.net' hash=<hash>
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-PEER-ALT depth=0 DNS:aut01rcsntx.rcsntx.sbcglobal.net
  wpa_supplicant[3351]: eth2: CTRL-EVENT-EAP-SUCCESS EAP authentication completed successfully
  ```
12. Reboot and make sure all of the interfaces come up succesfully. If you need to log back in to do troubleshooting you can use the serial console or with SSH and the local IP address.
 
##### Sources and References
* https://pastebin.com/SUGLTfv4
* https://en.wikipedia.org/wiki/IEEE_802.1X
* https://www.dupuis.xyz/bgw210-700-root-and-certs/
* http://earlz.net/view/2012/06/07/0026/rooting-the-nvg510-from-the-webui
* https://www.reddit.com/r/ATT/comments/g59rwm/bgw210700_root_exploitbypass/
* https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
* https://gist.github.com/physhster/ed0ce1d776e09fd5047c7a7c1c7bcd62#file-usg-wpa-supplicant-config-for-at-t-fiber-L31
