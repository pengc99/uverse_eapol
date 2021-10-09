###### Background
AT&T Uverse service is a triple-play service (internet, phone, and TV) provided by AT&T - depending on what service is available in your area you may be getting FTTH (Fiber to the Home), FTTN (Fiber to the Node), or VDSL (either bonded or unbonded).

FTTN and VDSL both use VDSL2 connectivity from your house to the network. The advantage with FTTN over FTTH is reduced deployment costs for MDUs (Multiple Dwelling Units, such as condos or apartment complexes) - AT&T only has to run fiber to a local node that then serves VDSL2 to the customers.

The problem isn't the service, the problem is with the Residential Gateway that AT&T provides. It's a decently powerful unit that allows for triple play services. However, there are a lot of limitations in the RG, namely the limitation of ~8000 NAT sessions, a poor interface with very limited options, and no true passthrough.

But wait! IP Passthrough? Why not just use that? The problem is **if you're using IP Passthrough, the RG still tracks all connections going through the RG**. Once you hit the connection limit of 8000 connections, which admittedly is more than most people need, the RG will refuse new connections. 

I've also had some instances where the RG will spontaneously reboot or crash and hang when under heavy usage. I needed to explore options on how to bypass the RG and use my own (hopefully more sane) DSL modem that doesn't do any connection tracking is just a pure layer 2 bridge between AT&T's VDSL network and my router. 

Doing some research, my particular VDSL service is unbonded so it only uses one pair of copper lines. This is important because the DSL interface I'm using in this guide does not support bonded mode. 

Additionally, this is valid only for people using UVerse for internet only - if you have any other service such as TV or phone service through Uverse, this will not work for you. You'll get unfiltered internet access, but will not be able to access TV or phone service.

Why use a DSL SFP module, and not a regular consumer DSL modem? The reason for this is because every consumer DSL modem I've found uses PPPoE authentication, while Uverse uses EAPoL authentication. EAPoL authentication uses TLS based authentication with certificates, instead of a username and password. There are a few benefits to this, namely authentication is provided by certificates and not usernames and passwords, and also there is no need for MTU shifting.

There are also modems that claim to use be a "Bridge Modem", or a device that simply handles the DSL training, and then bridges the DSL interface to the Ethernet interface. However, EAPoL packets are not forwarded across bridges by design, and out of the handful of DSL "Bridge Modems" I've tried such as the Netgear DM200 or Zyxel VMG4500 do not forward EAPoL authentication packets.

The working solution I've been using is to use a SFP DSL module, which will plug into high-end consumer routers that have SFP ports or commercial \ industrial routers. I found a few companies selling DSL SFP modules and sent out a few emails asking for technical information; namely I was looking for modules that would pass EAPoL packets.

Of the companies I emailed, one replied with a slightly vague response (Versatek), one replied saying they were not interested in helping individuals (Proscend), and one responded almost immediately with actual helpful information (Netsys), stating that their modules will pass EAPoL packets. Hats off to Terry at Netsys for being so helpful and willing to answer technical questions!

In the end the decision was simple; I ordered a Netsys 100SFP-S DSL SFP module for $99 and eagerly awaited it's arrival. You can find more information about their DSL SFP module here: https://www.netsys-direct.com/collections/dsl-products/products/long-reach-ethernet-over-vdsl2-sfp-cpe-slave-nv-100sfp-s

###### Hardware Needed 
* Netsys 100SFP-S VDSL SFP module
* AT&T Uverse Router / Gateway BGW210-700
* A router that is capable of setting VLANs on the WAN / Ethernet interface, and has an SFP port
  * I'm using a Ubiquiti Unifi Security Gateway Pro 4 port. Any prosumer or professional router should allow you to set the VLAN on the WAN interface, but I haven't seen this option in consumer Linksys / Netgear etc type routers. You may need to flash an alternative firmware like OpenWRT to get this if you have a consumer grade router. Additionally, if your router does not have an SFP port, you can also just build a device that bridges an SFP module to an Ethernet interface, but that is left as an exercise for the reader. 

###### Software Needed 
* curl (already installed on recent Windows 10 builds)
* 7zip - https://www.7-zip.org/
* FileZilla - https://filezilla-project.org/
* PuTTY - https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
* mfg_dat_decode - https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
  * Your computer may detect malware and prevent you from downloading this file. If it makes you uncomfortable, you can run it in a VM and destroy the VM when you're done. 
* AT&T UVerse RG firmware archive - https://mega.nz/file/35lBkbzC#MTrKdt57SEuz81Tn3MBKm-o_s1zv643MLmxyKILjsk8

###### Extract Certificates From AT&T UVerse RG 
1. Unzip AT&T RG Uverse firmware package - we're looking for `spTurquoise210-700_1.0.29.bin`
2. Disconnect the DSL cable from the UVerse RG. 
3. Log into your UVerse RG and downgrade the firmware with the above firmware file. The process takes several minutes and modem will reboot. 
4. After the RG is running again, go to http://192.168.1.254/cgi-bin/ipalloc.ha and assign yourself a static IP address
5. Refresh your computer's IP address to make sure you have the private IP address that was assigned.
6. Log into the UVerse RG again and authenticate
7. Run the following curl commands to start a telnet server on the UVerse modem. When prompted for the password for the user ''tech'', just hit ''ENTER''. After the last command is executed, the UVerse RG will reboot. 
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
8. Log into the UVerse RG with PuTTY using the IP address 192.168.1.254 on port 28 using the Telnet selection
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
14. ~~>Throw the UVerse RG into the garbage~~
    * Don't actually throw it in the garbage, you need to return it when you terminate your service with AT&T otherwise they will bill you a hefty sum.
    * Using the firmware archive that was downloaded earlier, you can step the UVerse back up to the current firmware by flashing 1.0.29, then 1.5.12, then 2.7.1
15. Extract the `mfg_dat_decode` utility that was downloaded earlier
16. Extract the `certs.tar.gz` archive that was downloaded earlier
17. Copy the `mfg.dat` file into the folder with the `mfg_dat_decode binary`
18. Copy all of the certificates extracted from `certs.tar.gz` into the folder with the `mfg_dat_decode` binary
19. Run the `mfg_dat_decode` binary, which will extract and create a tar.gz containing certificates and a `wpa_supplicant.conf` configuration file.
20. Extract the tar.gz file - you'll end up with a directory that contains three `pem` formatted certificates, a sample `wpa_supplicant.conf` file, and a `readme.txt` file. 

###### Generate / Uplink wpa_supplicant Files
  -Create a new text file, and paste the following into it and save it as ''99_dsl_eapol.sh'' - you can also just click on the link below and download it.<code - 99_dsl_eapol.sh>#!/bin/sh

logger -t DSL "$DSL_NOTIFICATION_TYPE $DSL_INTERFACE_STATUS"

if [ "$DSL_NOTIFICATION_TYPE" = "DSL_INTERFACE_STATUS" ] && [ "$DSL_INTERFACE_STATUS" = "UP" ]; then
        logger -t DSL "DSL interface UP, starting wpa_supplicant..."
        /usr/sbin/wpa_supplicant -s -B -P /var/run/wpa_supplicant.pid -D wired -i dsl0 -b br-br0 -c /etc/wpa_supplicant/wpa_supplicant.conf
        ip link set eth0 down
        sleep 5
        ip link set eth0 up
fi

if [ "$DSL_NOTIFICATION_TYPE" = "DSL_INTERFACE_STATUS" ] && [ "$DSL_INTERFACE_STATUS" = "DOWN" ]; then
        logger -t DSL "DSL interface DOWN, killing wpa_supplicant..."
        if [ -e /var/run/wpa_supplicant.pid ]; then
                kill $(cat /tmp/run/wpa_supplicant.pid)
        fi
        ip link set eth0 down
fi
</code>
  -Edit the ''wpa_supplicant.conf'' file using a text editor. 
    *Look for the lines that start with ''ca_cert'', ''client_cert'', and ''private_key'' and add ''/etc/wpa_supplicant/'' before the filename. For example: <code>ca_cert="/etc/wpa_supplicant/CA_001E46-27058949910000.pem"
client_cert="/etc/wpa_supplicant/Client_001E46-27058949910000.pem"
eap=TLS
eapol_flags=0
identity="18:9C:27:18:ED:F1" # Internet (ONT) interface MAC address must match this value
key_mgmt=IEEE8021X
phase1="allow_canned_success=1 tls_disable_time_checks=1"
private_key="/etc/wpa_supplicant/PrivateKey_PKCS1_001E46-27058949910000.pem"</code>
  -Open FileZilla and connect to the DM200 modem using the sftp protocol as the ''root''
  -Create a new directory ''/etc/wpa_supplicant''
  -Upload the ''wpa_supplicant.conf'' file and the three ''pem'' encoded certificates to ''/etc/wpa_supplicant''
  -Upload the ''99_dsl_eapol.sh'' file to ''/etc/hotplug.d/dsl'' and apply 0755 / -rwxr-xr-x permissions
  -**Do not reboot the DM200 from now on, otherwise you will need to factory reset the DM200 and start over**
== Configure the DM200 And Go Online! ==
  -Log into the web interface for the DM200, and delete all of the interfaces. On my default configuration, there was a eth0, dsl0 and dsl0-ipv6 interface. 
  -Create a new ''eth0'' interface and set it to unmanaged
  -Create a new ''dsl0'' interface and set it to unmanaged
  -Create a new ''br0'' bridge interface with ''eth0'' and ''dsl0'' as slave interfaces, and set it to unmanaged
  -Apply changes **without verification** - at this point the modem will disappear from the network. Wait a few minutes, and then turn it off.
  -Connect the Ethernet cable to your router and the DSL cable to the phone line.
  -Set the WAN interface on your router to use ''vlan 0''
  -Turn on the DM200. After a few minutes it should synchronize and train the DSL line. When training is complete, the DSL light will stop blinking and turn solid green.
  -A few seconds after the DSL light turns solid green, the Ethernet light should turn off and then back on after 5 seconds. 
  -At this point the DSL modem should have authenticated using EAPOL using ''wpa_supplicant'', and you should be able to get a IP address and access the internet!

====== Known Problems ======
  *DSL training sometimes gets hung up on the DM200. This only happens with the OpenWRT firmware and I haven't been able to figure out why. Power cycling usually solves the problem. 
  *Currently there is no way to access the DM200 to configure or view settings. On most DSL / cable modems, it is accessible on a static IP address such as ''192.168.100.1'' or ''192.168.5.1'' even after it has connected to the ISP network. I tried assigning an IP address to the bridge interface on the DM200, but I still can't access it.
    *The only way to get into the modem now is through the UART, which is documented [[https://openwrt.org/toh/netgear/dm200|here]]. I used the Adafruit UART to USB cable and connected to the serial console using PuTTY. Pressing ''ENTER'' after connecting will drop you into a root shell.
  *The DM200 gets HOT in usage. Probably worth investigating how to cool it better, some scattered reports that the DM200 might not be the most reliable DSL modem because of the heat it generates. 
== Sources and References ==
  * https://pastebin.com/SUGLTfv4
  * https://openwrt.org/toh/netgear/dm200
  * https://en.wikipedia.org/wiki/IEEE_802.1X
  * https://www.dupuis.xyz/bgw210-700-root-and-certs/
  * http://earlz.net/view/2012/06/07/0026/rooting-the-nvg510-from-the-webui
  * https://www.reddit.com/r/ATT/comments/g59rwm/bgw210700_root_exploitbypass/
  * https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
