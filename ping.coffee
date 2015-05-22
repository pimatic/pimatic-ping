module.exports = (env) ->
  # ##Dependencies
  util = require 'util'

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'

  ping = env.ping or require("net-ping")
  dns = env.dns or require("dns")

  # ##The PingPlugin
  class PingPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      @deviceCount = 0

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("PingPresence", {
        configDef: deviceConfigDef.PingPresents, 
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

      doPing = ( =>
        dns.lookup(@config.host, (dnsError, address, family) =>
          if !dnsError
            pendingPingsCount++
            @session.pingHost(address, (error, target) =>
              if pendingPingsCount > 0
                pendingPingsCount--
              @_setPresence (if error then no else yes)
              if pendingPingsCount is 0
                setTimeout(doPing, @config.interval)
            )
        )
      )

      doPing()

    getPresence: ->
      if @_presence? then return Promise.resolve @_presence
      return new Promise( (resolve, reject) =>
        @once('presence', ( (state) -> resolve state ) )
      ).timeout(@config.timeout + 5*60*1000)

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin