pimatic ping plugin
===================

Provides presence sensors for your wifi device, so actions can be triggered
if a wifi device is (or is not) present.

Providided predicates
---------------------
Add the plugin to the plugin section:

    { 
      "plugin": "ping"
    }

Then add a sensor for your device to the devices section:

    {
      "id": "my-phone",
      "name": "my smartphone",
      "class": "PingPresence",
      "host": "192.168.1.26",
      "interval": 5000
    }

Then you can use the predicates:

 * `"my smartphone is present"` or `"my-phone is present"`
 * `"my smartphone is not present"` or `"my-phone is not present"`
