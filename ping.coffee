module.exports = (env) ->
  # ##Dependencies
  util = require 'util'
  os = require 'os'
  net = require 'net'

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'

  ping = env.ping or require("net-ping")
  dns = env.dns or require("dns")

  # ##The PingPlugin
  class PingPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # ping package needs root access...
      if os.platform() isnt 'win32' and process.getuid() != 0
        throw new Error "ping-plugins needs root privileges. Please restart the framework as root!"
      @deviceCount = 0

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("PingPresence", {
        configDef: deviceConfigDef.PingPresence,
        createCallback: (config, lastState) => 
          device = new PingPresence(config, lastState, @deviceCount)
          @deviceCount++
          return device
      })

  pingPlugin = new PingPlugin

  # ##PingPresence Sensor
  class PingPresence extends env.devices.PresenceSensor

    constructor: (@config, lastState, deviceNum) ->
      @name = @config.name
      @id = @config.id
      @_presence = lastState?.presence?.value or false
      
      @session = ping.createSession(
        networkProtocol: ping.NetworkProtocol.IPv4
        packetSize: 16
        retries: @config.retries
        sessionId: ((process.pid + deviceNum) % 65535)
        timeout: @config.timeout
        ttl: 128
      )
      super()

      pendingPingsCount = 0
      lastError = null
      doPing = ( =>
        @_resolveHost(@config.host, (dnsError, addresses) =>
          if dnsError?
            if lastError?.message isnt dnsError.message
              env.logger.warn("Error on ip lookup of #{@config.host}: #{dnsError}")
              lastError = dnsError
            @_setPresence(no)
            setTimeout(doPing, @config.interval) if pendingPingsCount is 0
          else
            pendingPingsCount++
            Promise.some(@_pingHost address for address in addresses, 1).then((target) =>
              @_setPresence yes
            ).catch( =>
              @_setPresence no
            ).finally( =>
              pendingPingsCount-- if pendingPingsCount > 0
              setTimeout(doPing, @config.interval) if pendingPingsCount is 0
            )
        )
      )

      doPing()

    _resolveHost: (hostOrIP, cb) ->
      result = net.isIP hostOrIP
      if result is 4 or result is 6
        cb null, [hostOrIP]
      else
        dns.resolve4 hostOrIP, cb

    _pingHost: (address) ->
      return new Promise( (resolve, reject) =>
        @session.pingHost(address, (error, target) =>
          if error? then reject error else resolve target
        )
      )

    getPresence: ->
      if @_presence? then return Promise.resolve @_presence
      return new Promise( (resolve) =>
        @once('presence', ( (state) -> resolve state ) )
      ).timeout(@config.timeout + 5*60*1000)

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin