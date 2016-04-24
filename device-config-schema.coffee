module.exports = {
  title: "pimatic-ping device config schemas"
  PingPresence: {
    title: "PingPresence config options"
    type: "object"
    extensions: ["xLink", "xPresentLabel", "xAbsentLabel"]
    properties:
      host:
        description: "the ip or hostname to ping"
        type: "string"
        default: ""
      interval:
        description: "the delay between pings in milliseconds"
        type: "number"
        default: 5000
      timeout:
        description: "the time after a ping request timeouts in milliseconds"
        type: "number"
        default: 2000
      retries:
        description: "number of tries to fail after that the device is considered absent"
        type: "number"
        default: 4
      dnsRecordFamily:
        description: "the family of DNS address records returned, 4: IPv4, 6: IPv6, 10: both, 0: any"
        enum: [4, 6, 10, 0]
        default: 4
  }
}
