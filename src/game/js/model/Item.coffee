define ['lib/backbone', 'model/sockets'], (Backbone, sockets) ->

  # Client cache of items.
  # Wired to the server through socket.io
  class Items extends Backbone.Collection

    # **private**
    # flag to avoid multiple concurrent server call.
    _fetchRunning: false

    constructor: (@model, @options) ->
      super model, options
      # connect server response callbacks
      sockets.game.on 'consultMap-resp', @_onSync
      sockets.updates.on 'update', @_onUpdate

    # Provide a custom sync method to wire Items to the server.
    # Allows to retrieve items by coordinates.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    # @option args lowX [Number] abscissa lower bound (included)
    # @option args lowY [Number] ordinate lower bound (included)
    # @option args upX [Number] abscissa upper bound (included)
    # @option args upY [Number] ordinate upper bound (included)  
    sync: (method, instance, args) =>
      switch method
        when 'read'
          return if @_fetchRunning
          @_fetchRunning = true
          console.log "Consult map #{args.map} between #{args.lowX}:#{args.lowY} and #{args.upX}:#{args.upY}"
          # emit the message on the socket.
          sockets.game.emit 'consultMap', args.map, args.lowX, args.lowY, args.upX, args.upY

        else 
          throw new Error "Unsupported #{method} operation on Items"

    # **private**
    # Return callback of consultMap server operation.
    #
    # @param err [String] error string. null if no error occured
    # @param items [Array<Item>] array (may be empty) of concerned items.
    _onSync: (err, items) =>
      if @_fetchRunning
        @_fetchRunning = false
        return console.err "Fail to retrieve map content: #{err}" if err?
        console.log "#{items.length} map item(s) received"
        # add them to the collection (Item model will be created)
        @add items

    # **private**
    # Callback invoked when a database update is received.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given item.
    _onUpdate: (className, changes) =>
      return unless className is 'Item'
      # first, get the cached item and quit if not found
      item = @get changes._id
      return unless item?
      # then, update the local cache.
      for key, value of changes
        item.set key, value if key isnt '_id' and key isnt 'type'
      # emit a change.
      @trigger 'update', item


    # Override of the inherited method to disabled default behaviour.
    # DO NOT reset anything on fetch.
    reset: =>


  # Modelisation of a single Item.
  # Not wired to the server : use collections Items instead
  class Item extends Backbone.Model

    # item local cache.
    # A Backbone.Collection subclass that handle Items retrieval with `fetch()`
    @collection = new Items @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Item constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Item