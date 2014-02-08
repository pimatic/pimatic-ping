module.exports = (env) ->
  # ##Dependencies
  util = require 'util'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  convict = env.require "convict"
  _ = env.require 'lodash'

  ping = env.ping or require("net-ping")

  # ##The PingPlugin
  class PingPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      @deviceCount = 0


    createDevice: (config) ->
      #some legacy support:
      if config.class is 'PingPresents' then config.class = 'PingPresence'

      if config.class is 'PingPresence'
        assert config.id?
        assert config.name?
        sensor = new PingPresence config
        @framework.registerDevice sensor, @deviceCount
        @deviceCount++
        return true
      return false


  pingPlugin = new PingPlugin

  # ##PingPresence Sensor
  class PingPresence extends env.devices.PresenceSensor

    constructor: (deviceConfig, deviceNum) ->
      configSchema = _.cloneDeep(require("./device-config-schema"))
      @conf = convict configSchema
      @conf.load deviceConfig
      @conf.validate()
      @name = @conf.get "name"
      @id = @conf.get "id"
      @host = @conf.get "host"
      @timeout = @conf.get "timeout"
      @retries = @conf.get "retries"
      # some legazy support: delay is now interval
      if deviceConfig.delay?
        @interval = deviceConfig.delay
        delete deviceConfig.delay
        deviceConfig.interval = @interval 
      else
        @interval = @conf.get "interval"

      @session = ping.createSession(
        networkProtocol: ping.NetworkProtocol.IPv4
        packetSize: 16
        retries: @retries
        sessionId: ((process.pid + deviceNum) % 65535)
        timeout: @timeout
        ttl: 128
      )
      super()

      pendingPingsCount = 0

      ping = => 
        pendingPingsCount++
        @session.pingHost(@host, (error, target) =>
          pendingPingsCount--
          #env.logger.debug error
          @_setPresence (if error then no else yes)
          assert pendingPingsCount is 0
          setTimeout(ping, @interval)    
        )

      ping()

    getPresence: ->
      if @_presence? then return Q @_presence
      deferred = Q.defer()
      @once 'presence', (presence)=>
        deferred.resolve presence
      return deferred.promise

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin