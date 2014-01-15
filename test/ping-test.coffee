module.exports = (env) ->

  assert = env.require "cassert"

  describe "pimatic-ping", ->

    plugin = (require 'pimatic-ping') env
    PingPresence = plugin.PingPresence

    beforeEach =>
      @sessionDummy = 
        pingHost: (host, callback) =>
      config =
        id: 'test'
        name: 'test device'
        host: 'localhost'
        delay: 200
      @sensor = new PingPresence(config, @sessionDummy)

    describe '#on presence', =>

      it "should notify when device is presence", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          assert host is "localhost"
          setTimeout () =>
            callback null, host
          ,22

        listener = (presence) =>
          assert presence is true
          @sensor.removeListener 'presence', listener
          finish()

        @sensor.on 'presence', listener

      it "should notify when device is not presence", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          assert host is "localhost"
          setTimeout =>
            callback new Error('foo'), host
          ,22

        listener = (presence) =>
          assert presence is false
          @sensor.removeListener 'presence', listener
          finish()

        @sensor.on 'presence', listener
