module.exports =
  PingPresents:
    host:
      description: "the ip or hostname to ping"
      type: "string"
      default: ""
    interval:
      description: "the delay between pings"
      type: "number"
      default: 5000
    timeout:
      description: "the time after a ping request timeouts"
      type: "number"
      default: 2000
    retries:
      description: "number of tries to fail after that the device is considerd absent"
      type: "number"
      default: 4