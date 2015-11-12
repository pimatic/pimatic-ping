pimatic ping plugin
===================

Provides presence sensors for your wifi device, so actions can be triggered
if a wifi device is (or is not) present.

Configuration
-------------
Add the plugin to the plugin section:

    { 
      "plugin": "ping"
    }

Then add a presence sensor for your device to the devices section:

    {
      "id": "my-phone",
      "name": "my smartphone",
      "class": "PingPresence",
      "host": "192.168.1.26",
      "interval": 5000
    }
    
The host property can also be set to a hostname which will be resolved using DNS. By default, DNS will be queried
for IPv4 addresses. If multiple IP addresses found the device will be flagged present if at least one IP address 
can be successfully pinged. By setting the property `dnsRecordFamily` to one of the following numbers the 
DNS address resolution mode can be selected:

 * ` 4`: query IPv4 addresses (default)
 * ` 6`: query IPv6 addresses
 * `10`: hybrid mode, query IPv4 and IPv6 addresses
 * ` 0`: any mode, query IPv4 and IPv6 addresses, but use whatever query result is returned first

Provided predicates
-------------------
You can use the predicates:

 * `"my smartphone is present"` or `"my-phone is present"`
 * `"my smartphone is not present"` or `"my-phone is not present"`
