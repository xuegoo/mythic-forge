###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###

server = require '../src/web/server'
Player = require '../src/model/Player'
utils = require '../src/utils'
request = require 'request'
parseUrl = require('url').parse
assert = require('chai').assert

port = utils.confKey 'server.apiPort'
rootUrl = "http://localhost:#{port}"

describe.skip 'Authentication tests', ->

  before (done) ->
    Player.collection.drop (err)->
      return done err if err?
      server.listen port, 'localhost', done

  # Restore admin player for further tests
  after (done) ->
    server.close()
    new Player(email:'admin', password: 'admin', isAdmin:true).save done

  describe 'given a started server', ->

    token = null
    lastConnection = null

    describe 'given a Twitter account', ->

      twitterUser = "MythicForgeTest"
      twitterPassword = "toto1818"

      it 'should Twitter user be enrolled', (done) ->
        @timeout 20000

        # when requesting the twitter authentication page
        request "#{rootUrl}/auth/twitter", (err, res, body) ->
          throw new Error err if err?
          # then the twitter authentication page is displayed
          assert.equal 'api.twitter.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          assert.ok -1 != body.indexOf('id="username_or_email"'), 'No email found in response'
          assert.ok -1 != body.indexOf('id="password"'), 'No password found in response'

          # forge form to log-in
          form = 
            'session[username_or_email]': twitterUser
            'session[password]': twitterPassword
            authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
            oauth_token: body.match(/name\s*=\s*"oauth_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
            forge_login: 1

          # when registering with test account
          request 
            uri: 'https://api.twitter.com/oauth/authenticate'
            method: 'POST'
            form: form
          , (err, res, body) ->
            throw new Error err if err?

            # manually follw redirection
            redirect = body.match(/<a\s+href\s*=\s*"(http:\/\/localhost:[^"]*)"/)[1]
            request redirect, (err, res, body) ->
              throw new Error err if err?

              # then the success page is displayed
              assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
              token = parseUrl(res.request.uri.href).query.replace 'token=', ''
              assert.isNotNull token
              # then account has been created and populated
              Player.findOne {email:twitterUser}, (err, saved) ->
                throw new Error "Failed to find created account in db: #{err}" if err?
                assert.equal saved.firstName, 'Bauer'
                assert.equal saved.lastName, 'Jack'
                assert.equal saved.token, token
                assert.isNotNull saved.lastConnection
                lastConnection = saved.lastConnection
                done()   

      it 'should existing logged-in Twitter user be immediately authenticated', (done) ->
        @timeout 10000

        # when requesting the twitter authentication page while a twitter user is already logged-in
        request "#{rootUrl}/auth/twitter", (err, res, body) ->
          throw new Error err if err?

          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
          assert.isNotNull token2
          assert.notEqual token2, token
          token = token2
          # then account has been updated with new token
          Player.findOne {email:twitterUser}, (err, saved) ->
            throw new Error "Failed to find created account in db: #{err}" if err?
            assert.equal saved.token, token2
            assert.isNotNull saved.lastConnection
            assert.notEqual lastConnection, saved.lastConnection
            done()    

      it 'should existing Twitter user be authenticated after log-in', (done) ->
        @timeout 20000

        # given an existing but not logged in Twitter account
        request 'http://twitter.com/logout', (err, res, body) ->
          throw new Error err if err?

          request 
            uri: 'https://twitter.com/logout'
            method: 'POST'
            form:
              authenticity_token: body.match(/value\s*=\s*"([^"]*)"\s+name\s*=\s*"authenticity_token"/)[1]
          , (err, res, body) ->
            throw new Error err if err?

            # when requesting the twitter authentication page
            request "#{rootUrl}/auth/twitter", (err, res, body) ->
              throw new Error err if err?
              # then the twitter authentication page is displayed
              assert.equal 'api.twitter.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
              assert.ok -1 != body.indexOf('id="username_or_email"'), 'No email found in response'
              assert.ok -1 != body.indexOf('id="password"'), 'No password found in response'

              # forge form to log-in
              form = 
                'session[username_or_email]': twitterUser
                'session[password]': twitterPassword
                authenticity_token: body.match(/name\s*=\s*"authenticity_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
                oauth_token: body.match(/name\s*=\s*"oauth_token"\s+type\s*=\s*"hidden"\s+value\s*=\s*"([^"]*)"/)[1]
                forge_login: 1

              # when registering with test account
              request 
                uri: 'https://api.twitter.com/oauth/authenticate'
                method: 'POST'
                form: form
              , (err, res, body) ->
                throw new Error err if err?

                # manually follw redirection
                redirect = body.match(/<a\s+href\s*=\s*"(http:\/\/localhost:[^"]*)"/)[1]
                request redirect, (err, res, body) ->
                  throw new Error err if err?

                  # then the success page is displayed
                  assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
                  token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
                  assert.isNotNull token2
                  assert.notEqual token2, token
                  # then account has been updated with new token
                  Player.findOne {email:twitterUser}, (err, saved) ->
                    throw new Error "Failed to find created account in db: #{err}" if err?
                    assert.equal saved.token, token2
                    assert.isNotNull saved.lastConnection
                    assert.notEqual lastConnection, saved.lastConnection
                    done()
    describe 'given a Google account', ->

      googleUser = "mythic.forge.test@gmail.com"
      googlePassword = "toto1818"

      it 'should Google user be enrolled', (done) ->
        @timeout 20000

        # when requesting the google authentication page
        request "#{rootUrl}/auth/google", (err, res, body) ->
          throw new Error err if err?
          # then the google authentication page is displayed
          assert.equal 'accounts.google.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          assert.ok -1 != body.indexOf('id="Email"'), 'No email found in response'
          assert.ok -1 != body.indexOf('id="Passwd"'), 'No password found in response'

          # forge form to log-in
          form = 
            Email: googleUser
            GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
            Passwd: googlePassword
            checkConnection: 'youtube:248:1'
            checkedDomains: 'youtube'
            continue: body.match(/id\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
            pstMsg: 1
            scc: 1
            service: 'lso'

          # when registering with test account
          request 
            uri: 'https://accounts.google.com/ServiceLoginAuth'
            method: 'POST'
            form: form
          , (err, res, body) ->
            throw new Error err if err?

            # manually follw redirection
            redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')
            request redirect, (err, res, body) ->
              throw new Error err if err?

              # accepts to give access to account informations
              request 
                uri: body.match(/<form action="([^"]*)"/)[1].replace(/&amp;/g, '&')
                method: 'POST'
                followAllRedirects: true
                form: 
                  state_wrapper: body.match(/name\s*=\s*"state_wrapper"\s+value\s*=\s*"([^"]*)"/)[1]
                  submit_access: true

              , (err, res, body) ->
                throw new Error err if err?

                # then the success page is displayed
                assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
                token = parseUrl(res.request.uri.href).query.replace 'token=', ''
                assert.isNotNull token
                # then account has been created and populated
                Player.findOne {email:googleUser}, (err, saved) ->
                  throw new Error "Failed to find created account in db: #{err}" if err?
                  assert.equal saved.firstName, 'John'
                  assert.equal saved.lastName, 'Doe'
                  assert.equal saved.token, token
                  assert.isNotNull saved.lastConnection
                  lastConnection = saved.lastConnection
                  done()     

      it 'should existing logged-in Google user be immediately authenticated', (done) ->
        @timeout 10000

        # when requesting the google authentication page while a google user is already logged-in
        request "#{rootUrl}/auth/google", (err, res, body) ->
          throw new Error err if err?
          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
          assert.isNotNull token2
          assert.notEqual token2, token
          token = token2
          # then account has been updated with new token
          Player.findOne {email:googleUser}, (err, saved) ->
            throw new Error "Failed to find created account in db: #{err}" if err?
            assert.equal saved.token, token2
            assert.isNotNull saved.lastConnection
            assert.notEqual lastConnection, saved.lastConnection
            done()    

      it 'should existing Google user be authenticated after log-in', (done) ->
        @timeout 20000

        # given an existing but not logged in Google account
        request "https://code.google.com/apis/console/logout", (err, res, body) ->
          throw new Error err if err?

          # when requesting the google authentication page
          request "#{rootUrl}/auth/google", (err, res, body) ->
            throw new Error err if err?
            # then the google authentication page is displayed
            assert.equal 'accounts.google.com', res.request.uri.host, "Wrong host: #{res.request.uri.host}"
            assert.ok -1 != body.indexOf('id="Email"'), 'No email found in response'
            assert.ok -1 != body.indexOf('id="Passwd"'), 'No password found in response'

            # forge form to log-in
            form = 
              Email: googleUser
              GALX: body.match(/name\s*=\s*"GALX"\s+value\s*=\s*"([^"]*)"/)[1]
              Passwd: googlePassword
              checkConnection: 'youtube:248:1'
              checkedDomains: 'youtube'
              continue: body.match(/id\s*=\s*"continue"\s+value\s*=\s*"([^"]*)"/)[1]
              pstMsg: 1
              scc: 1
              service: 'lso'

            # when registering with test account
            request 
              uri: 'https://accounts.google.com/ServiceLoginAuth'
              method: 'POST'
              form: form
            , (err, res, body) ->
              throw new Error err if err?

              # manually follw redirection
              redirect = body.match(/window.__CONTINUE_URL\s*=\s*'([^']*)'/)[1].replace(/\\x2F/g, '/').replace(/\\x26amp%3B/g, '&')
              request redirect, (err, res, body) ->
                throw new Error err if err?

                # then the success page is displayed
                assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
                token2 = parseUrl(res.request.uri.href).query.replace 'token=', ''
                assert.isNotNull token2
                assert.notEqual token2, token
                # then account has been updated with new token
                Player.findOne {email:googleUser}, (err, saved) ->
                  throw new Error "Failed to find created account in db: #{err}" if err?
                  assert.equal saved.token, token2
                  assert.isNotNull saved.lastConnection
                  assert.notEqual lastConnection, saved.lastConnection
                  done()

    describe 'given a manually created player', ->

      player = null
      clearPassword = 'dams'

      before (done) ->
        new Player(
          email: 'dams@test.com'
          password: clearPassword
        ).save (err, saved) -> 
          throw new Error err if err?
          player = saved
          done()

      it 'should user be authenticated', (done) ->

        # when sending a correct authentication form
        request 
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          followAllRedirects: true
          form:
            username: player.get 'email'
            password: clearPassword
        , (err, res, body) ->
          throw new Error err if err?
          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          query = parseUrl(res.request.uri.href).query
          assert.ok -1 is query.indexOf('error='), "Unexpected server error: #{query}"
          token = query.replace 'token=', ''
          assert.isNotNull token
          # then account has been populated with new token
          Player.findOne {email:player.get 'email'}, (err, saved) ->
            throw new Error "Failed to find created account in db: #{err}" if err?
            assert.equal saved.token, token
            assert.isNotNull saved.lastConnection
            lastConnection = saved.lastConnection
            done()   

      it 'should user not be authenticated with wrong password', (done) ->

        # when sending a wrong password authentication form
        request 
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          followAllRedirects: true
          form:
            username: player.get 'email'
            password: 'toto'
        , (err, res, body) ->
          throw new Error err if err?
          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          query = parseUrl(res.request.uri.href).query
          assert.ok -1 isnt query.indexOf('Wrong%20credentials'), "unexpected error #{query}"
          done()   

      it 'should unknown user not be authenticated', (done) ->

        # when sending an unknown account authentication form
        request 
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          followAllRedirects: true
          form:
            username: 'toto'
            password: 'titi'
        , (err, res, body) ->
          throw new Error err if err?
          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          query = parseUrl(res.request.uri.href).query
          assert.ok -1 isnt query.indexOf('Wrong%20credentials'), "unexpected error #{query}"
          done()   

      it 'should user not be authenticated without password', (done) ->

        # when sending a wrong password authentication form
        request 
          uri: "#{rootUrl}/auth/login"
          method: 'POST'
          followAllRedirects: true
          form:
            username: player.get 'email'
        , (err, res, body) ->
          throw new Error err if err?
          # then the success page is displayed
          assert.equal "localhost:#{utils.confKey 'server.apiPort'}", res.request.uri.host, "Wrong host: #{res.request.uri.host}"
          query = parseUrl(res.request.uri.href).query
          assert.ok -1 isnt query.indexOf('Missing%20credentials'), "unexpected error #{query}"
          done()  