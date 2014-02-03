# #gpio actuator configuration options

# Defines a `node-convict` config-schema and exports it.
module.exports =
  host:
    doc: "the ip or hostname to ping"
    format: String
    default: ""
  interval:
    doc: "the delay between pings"
    format: "nat"
    default: 5000
  timeout:
    doc: "the time after a ping request timeouts"
    format: "nat"
    default: 2000
  retries:
    doc: "number of tries to fail after that the device is considerd absent"
    format: "nat"
    default: 4