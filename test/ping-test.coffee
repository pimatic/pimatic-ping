module.exports = (env) ->

  assert = env.require "cassert"

  describe "pimatic-ping", ->

    plugin = (require 'pimatic-ping') env
    PingPresents = plugin.PingPresents

    beforeEach =>
      @sessionDummy = 
        pingHost: (host, callback) =>
      config =
        id: 'test'
        name: 'test device'
        host: 'localhost'
        delay: 200
      @sensor = new PingPresents(config, @sessionDummy)

    describe '#on present', =>

      it "should notify when device is present", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          assert host is "localhost"
          setTimeout () =>
            callback null, host
          ,22

        listener = (present) =>
          assert present is true
          @sensor.removeListener 'present', listener
          finish()

        @sensor.on 'present', listener

      it "should notify when device is not present", (finish) =>
        @sessionDummy.pingHost = (host, callback) =>
          assert host is "localhost"
          setTimeout =>
            callback new Error('foo'), host
          ,22

        listener = (present) =>
          assert present is false
          @sensor.removeListener 'present', listener
          finish()

        @sensor.on 'present', listener
