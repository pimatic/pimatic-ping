module.exports = (env) ->
  # ##Dependencies
  util = require 'util'
  os = require 'os'
  net = require 'net'

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'

  ping = env.ping or require("net-ping")
  resolve4 = Promise.promisify (env.dns or require "dns").resolve4
  resolve6 = Promise.promisify (env.dns or require "dns").resolve6

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

      @_resolve = resolve4
      if @config.dnsRecordFamily is 6
        @_resolve = resolve6
      else if @config.dnsRecordFamily is 0
        @_resolve = @_resolveAny
      else if @config.dnsRecordFamily is 10
        @_resolve = @_resolveHybrid


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
        pendingPingsCount++
        @_resolveHost(@config.host).then( (addresses) =>
          Promise.any(@_pingHost address for address in addresses).then( =>
            @_setPresence yes
          ).catch( =>
            @_setPresence no
          ).finally( =>
            pendingPingsCount-- if pendingPingsCount > 0
            setTimeout(doPing, @config.interval) if pendingPingsCount is 0
          )
        ).catch( (dnsError) =>
          if lastError?.message isnt dnsError.message
            env.logger.warn("Error on ip lookup of #{@config.host}: #{dnsError}")
            lastError = dnsError
          @_setPresence(no)
          pendingPingsCount-- if pendingPingsCount > 0
          setTimeout(doPing, @config.interval) if pendingPingsCount is 0
        )
      )
      doPing()

    _resolveHost: (hostOrIP) ->
      result = net.isIP hostOrIP
      if result is 4 or result is 6
        return Promise.resolve [hostOrIP]
      else
        @_resolve(hostOrIP)

    _pingHost: (address) ->
      return new Promise( (resolve, reject) =>
        @session.pingHost(address, (error, target) =>
          if pingPlugin.config.debug
            if error?
              errorMessage = if error.message? then error.message else error
            env.logger.debug "Ping", address, if errorMessage? then errorMessage else "alive"
          if error? then reject error else resolve target
        )
      )

    _resolveHybrid: (hostOrIP) ->
      # do both resolve4 and resolve6 queries, fails if both queries fail
      result = []
      return new Promise( (resolve, reject) =>
        resolve4(hostOrIP).then( (addresses) =>
          result = addresses
        ).catch(
          # intentionally left empty
        ).finally( =>
          resolve6(hostOrIP).then( (addresses) =>
            resolve result.concat addresses
          ).catch( (error) =>
            if result.length > 0
              resolve result
            else
              reject error
          )
        )
      )

    _resolveAny: (hostOrIP) ->
      return Promise.any([resolve4(hostOrIP), resolve6(hostOrIP)])

    getPresence: ->
      if @_presence?
        return Promise.resolve @_presence
      else
        return new Promise( (resolve) =>
          @once('presence', ( (state) -> resolve state ) )
        ).timeout(@config.timeout + 5*60*1000)

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin