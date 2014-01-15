module.exports = (env) ->
  # ##Dependencies
  util = require 'util'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'

  ping = require "net-ping"

  # ##The PingPlugin
  class PingPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # ping package needs root access...
      if process.getuid() != 0
        throw new Error "ping-plugins needs root privilegs. Please restart the framework as root!"
      @session = ping.createSession()

    createDevice: (config) ->
      if @session? and config.class is 'PingPresence'
        assert config.id?
        assert config.name?
        assert config.host? 
        config.delay = (if config.delay then config.delay else 3000)
        sensor = new PingPresence config, @session
        @framework.registerDevice sensor
        return true
      return false


  pingPlugin = new PingPlugin

  # ##PingPresence Sensor
  class PingPresence extends env.devices.PresenceSensor

    constructor: (@config, session) ->
      @id = config.id
      @name = config.name
      super()

      ping = => session.pingHost @config.host, (error, target) =>
        @_setPresence (if error then no else yes)

      @interval = setInterval(ping, config.delay)



  # For testing...
  pingPlugin.PingPresence = PingPresence

  return pingPlugin