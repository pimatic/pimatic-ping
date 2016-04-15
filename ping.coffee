module.exports = (env) ->
  # ##Dependencies
  util = require 'util'
  os = require 'os'
  net = require 'net'
  dns = require 'dns'

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

      @framework.deviceManager.on('discover', (eventData) =>
        interfaces = @listInterfaces()
        # ping all devices in each net:
        maxPings = 513
        pingCount = 0
        interfaces.forEach( (iface, ifNum) =>
          @framework.deviceManager.discoverMessage(
            'pimatic-ping', "Scanning #{iface.address}/24"
          )
          base = iface.address.match(/([0-9]+\.[0-9]+\.[0-9]+\.)[0-9]+/)[1]
          i = 1
          while i < 256
            do (i) =>
              if pingCount > maxPings then return
              address = "#{base}#{i}"
              sessionId = ((process.pid + (256*(ifNum+1)) + i) % 65535)
              session = ping.createSession(
                networkProtocol: ping.NetworkProtocol.IPv4
                packetSize: 16
                retries: 3
                sessionId: sessionId
                timeout: eventData.time
                ttl: 128
              )
              session.pingHost(address, (error, target) =>
                session.close()
                unless error
                  dns.reverse(address, (error, hostnames) =>
                    displayName = (
                      if hostnames? and hostnames.length > 0 then hostnames[0] else address
                    )
                    config = {
                      class: 'PingPresence',
                      name: displayName,
                      host: displayName
                    }
                    @framework.deviceManager.discoveredDevice(
                      'pimatic-ping', "Presence of #{displayName}", config
                    )
                  )
              )
            i++
            pingCount++
          if pingCount > maxPings
            @framework.deviceManager.discoverMessage(
              'pimatic-ping', "Could not ping all networks, max ping cound reached."
            )
        )
      )

    # get all ip4 non local networks with /24 submask
    listInterfaces : () ->
      interfaces = []
      ifaces = os.networkInterfaces()
      Object.keys(ifaces).forEach( (ifname) ->
        alias = 0
        ifaces[ifname].forEach (iface) ->
          if 'IPv4' isnt iface.family or iface.internal isnt false
            # skip over internal (i.e. 127.0.0.1) and non-ipv4 addresses
            return
          if iface.netmask isnt "255.255.255.0"
            return
          interfaces.push {name: ifname, address: iface.address}
        return
      )
      return interfaces


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
        if @_destroyed then return
        pendingPingsCount++
        @_resolveHost(@config.host).then( (addresses) =>
          Promise.any(@_pingHost address for address in addresses).then( =>
            unless @_destroyed then @_setPresence yes
          ).catch( =>
            unless @_destroyed then @_setPresence no
          ).finally( =>
            pendingPingsCount-- if pendingPingsCount > 0
            if @_destroyed then return
            setTimeout(doPing, @config.interval) if pendingPingsCount is 0
          )
        ).catch( (dnsError) =>
          if lastError?.message isnt dnsError.message
            env.logger.warn("Error on ip lookup of #{@config.host}: #{dnsError}")
            lastError = dnsError
          unless @_destroyed then @_setPresence(no)
          pendingPingsCount-- if pendingPingsCount > 0
          if @_destroyed then return
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

    destroy: ->
      super()
      @session.close()

  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin