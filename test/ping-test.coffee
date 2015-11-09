module.exports = (env) ->

  assert = require 'assert'
  cassert = env.require "cassert"

  describe "pimatic-ping", ->

    env.ping = {
      NetworkProtocol:
        IPv4: "IPv4"
    }
    plugin = (require 'pimatic-ping') env
    PingPresence = plugin.PingPresence

    sessionDummy = null

    before =>

      env.ping.createSession = (options) =>
        assert typeof options.sessionId is "number"
        assert.deepEqual options, { 
          networkProtocol: 'IPv4'
          packetSize: 16
          retries: 1
          sessionId: options.sessionId
          timeout: 2001
          ttl: 128 
        }

        return @sessionDummy = {
          pingHost: (host, callback) => callback(null, host)
        }

      config =
        id: 'test'
        name: 'test device'
        host: 'localhost'
        interval: 200
        retries: 1
        timeout: 2001

      @sensor = new PingPresence(config, false, 0)

    describe '#on presence', =>

      it "should notify when device is present", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          cassert host is "localhost"
          setTimeout( () =>
            callback null, host
          , 22)

        listener = (presence) =>
          cassert presence is true
          @sensor.removeListener 'presence', listener
          finish()

        @sensor._presence = false
        @sensor.on 'presence', listener

      it "should notify when device is not present", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          cassert host is "localhost"
          setTimeout( =>
            callback new Error('foo'), host
          , 22)

        listener = (presence) =>
          cassert presence is false
          @sensor.removeListener 'presence', listener
          finish()

        @sensor._presence = true
        @sensor.on 'presence', listener
