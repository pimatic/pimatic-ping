module.exports = (env) ->
  # ##Dependencies
  util = require 'util'

  Q = env.require 'q'
  assert = env.require 'cassert'
  _ = env.require 'lodash'

  ping = env.ping or require("net-ping")

  # ##The PingPlugin
  class PingPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      @deviceCount = 0

      deviceConfigDef = require("./device-config-schema")

      @framework.registerDeviceClass("PingPresence", {
        configDef: deviceConfigDef.PingPresents, 
        createCallback: (config) => 
          device = new PingPresence(config, @deviceCount)
          @deviceCount++
          return device
      })

  pingPlugin = new PingPlugin

  # ##PingPresence Sensor
  class PingPresence extends env.devices.PresenceSensor

    constructor: (@config, deviceNum) ->
      @name = @config.name
      @id = @config.id

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
        pendingPingsCount++
        @session.pingHost(@config.host, (error, target) =>
          if pendingPingsCount > 0
            pendingPingsCount--
          else
            env.logger.debug "ping callback called too many times"
          @_setPresence (if error then no else yes)
          if pendingPingsCount is 0
            setTimeout(doPing, @config.interval)
        )
      )

      doPing()

    getPresence: ->
      if @_presence? then return Q @_presence
      deferred = Q.defer()
      @once 'presence', (presence)=>
        deferred.resolve presence
      return deferred.promise

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin