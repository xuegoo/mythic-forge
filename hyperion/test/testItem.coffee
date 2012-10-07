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

Item = require '../src/model/Item'
ItemType = require '../src/model/ItemType'
Map = require '../src/model/Map'
watcher = require('../src/model/ModelWatcher').get()
assert = require('chai').assert

item = null
item2 = null
type = null
awaited = false

describe 'Item tests', -> 

  beforeEach (done) ->
    type = new ItemType({name: 'plain'})
    type.setProperty 'rocks', 'integer', 100
    type.save (err, saved) ->
      return done err if err?
      Item.collection.drop -> done()

  afterEach (end) ->
    ItemType.collection.drop -> Item.collection.drop -> end()

  it 'should item be created', (done) -> 
    # given a new Item
    item = new Item {x: 10, y:-3, type:type}

    # then a creation event was issued
    watcher.once 'change', (operation, className, instance)->
      assert.equal className, 'Item'
      assert.equal operation, 'creation'
      assert.ok item.equals instance
      awaited = true

    # when saving it
    awaited = false
    item.save (err) ->
      return done "Can't save item: #{err}" if err?

      # then it is in mongo
      Item.find {}, (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # then it's the only one document
        assert.equal docs.length, 1
        # then it's values were saved
        assert.equal docs[0].get('x'), 10
        assert.equal docs[0].get('y'), -3
        assert.ok awaited, 'watcher wasn\'t invoked'
        done()

  it 'should new item have default properties values', (done) ->
    # when creating an item of this type
    item = new Item {type: type}
    item.save (err)->
      return done "Can't save item: #{err}" if err?
      # then the default value was set
      assert.equal item.get('rocks'), 100
      done()

  describe 'given an Item', ->

    beforeEach (done) ->
      item = new Item {x: 150, y: 300, type: type}
      item.save -> done()

    it 'should item be removed', (done) ->
      # then a removal event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'deletion'
        assert.ok item.equals instance
        awaited = true

      # when removing an item
      awaited = false
      item.remove (err) ->
        return done err if err?

        # then it's not in mongo anymore
        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          assert.equal docs.length, 0
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should item be updated', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item.equals instance
        assert.equal instance.x, -100
        awaited = true

      # when modifying and saving an item
      item.set 'x', -100
      awaited = false
      item.save ->

        Item.find {}, (err, docs) ->
          return done "Can't find item: #{err}" if err?
          # then it's the only one document
          assert.equal docs.length, 1
          # then only the relevant values were modified
          assert.equal docs[0].get('x'), -100
          assert.equal docs[0].get('y'), 300
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should dynamic property be modified', (done) ->
      # then a modification event was issued
      watcher.once 'change', (operation, className, instance)->
        assert.equal className, 'Item'
        assert.equal operation, 'update'
        assert.ok item.equals instance
        assert.equal instance.rocks, 200
        awaited = true

      # when modifying a dynamic property
      item.set 'rocks', 200
      awaited = false
      item.save ->

        Item.findOne {_id: item._id}, (err, doc) ->
          return done "Can't find item: #{err}" if err?
          # then only the relevant values were modified
          assert.equal doc.get('x'), 150
          assert.equal doc.get('y'), 300
          assert.equal doc.get('rocks'), 200
          assert.ok awaited, 'watcher wasn\'t invoked'
          done()

    it 'should item cannot be saved with unknown property', (done) ->
      # when saving an item with an unknown property
      item.set 'test', true
      item.save (err)->
        # then an error is raised
        assert.fail 'An error must be raised when saving item with unknown property' if !err
        assert.ok err?.message.indexOf('unknown property test') isnt -1
        done()

    it 'should item be removed with map', (done) ->
      # given a map
      map = new Map(name: 'map1').save (err, map) ->
        return done err if err?
        # given a map item
        new Item(map: map, x: 0, y: 0, type: type).save (err, item2) ->
          return done err if err?
          Item.find {map: map._id}, (err, items) ->
            return done err if err?
            assert.equal items.length, 1

            changes = []
            # then only a removal event was issued
            watcher.on 'change', (operation, className, instance)->
              changes.push arguments

            # when removing the map
            map.remove (err) ->
              return done "Failed to remove map: #{err}" if err?

              # then items are not in mongo anymore
              Item.find {map: map._id}, (err, items) ->
                return done err if err?
                assert.equal items.length, 0
                assert.equal 1, changes.length, 'watcher wasn\'t invoked'
                assert.equal changes[0][1], 'Map'
                assert.equal changes[0][0], 'deletion'
                watcher.removeAllListeners 'change'
                done()

    it 'should quantity not be set on unquantifiable type', (done) ->
      # given a unquantifiable type
      type.set 'quantifiable', false
      type.save (err) ->
        return done err if err?
        # when setting quantity on item
        item.set 'quantity', 10
        item.save (err, saved) ->
          return done err if err?
          # then quantity is set to null
          assert.isNull saved.get 'quantity'
          done()

    it 'should quantity be set on quantifiable type', (done) ->
      # given a unquantifiable type
      type.set 'quantifiable', true
      type.save (err) ->
        return done err if err?
        # when setting quantity on item
        item.set 'quantity', 10
        item.save (err, saved) ->
          return done err if err?
          # then quantity is set to relevant quantity
          assert.equal 10, saved.get 'quantity'
          # when setting quantity to null
          item.set 'quantity', null
          item.save (err, saved) ->
            return done err if err?
            # then quantity is set to 0
            assert.equal 0, saved.get 'quantity'
            done()

  describe 'given a type with object properties and several Items', -> 

    beforeEach (done) ->
      type = new ItemType {name: 'river'}
      type.setProperty 'name', 'string', ''
      type.setProperty 'end', 'object', 'Item'
      type.setProperty 'affluents', 'array', 'Item'
      type.save ->
        Item.collection.drop -> 
          item = new Item {name: 'Rhône', end: null, type: type, affluents:[]}
          item.save (err, saved) ->
            return done err  if err?
            item = saved
            item2 = new Item {name: 'Durance', end: item, type: type, affluents:[]}
            item2.save (err, saved) -> 
              return done err  if err?
              item2 = saved
              item.set 'affluents', [item2]
              item.save (err) ->
                return done err  if err?
                done()

    it 'should id be stored for linked object', (done) ->
      # when retrieving an item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # then linked items are replaced by their ids
        assert.ok item._id.equals doc.get('end')
        done()

    it 'should ids be stored for linked arrays', (done) ->
      # when resolving an item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # then linked arrays are replaced by their ids
        assert.equal doc.get('affluents').length, 1
        assert.ok item2._id.equals doc.get('affluents')[0]
        done()

    it 'should resolve retrieves linked objects', (done) ->
      # given a unresolved item
      Item.findOne {name: item2.get 'name'}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.ok item._id.equals doc.get('end')._id
          assert.equal doc.get('end').get('name'), item.get('name')
          assert.equal doc.get('end').get('end'), item.get('end')
          assert.equal doc.get('end').get('affluents')[0], item.get('affluents')[0]
          done()

    it 'should resolve retrieves linked arrays', (done) ->
      # given a unresolved item
      Item.findOne {name: item.get 'name'}, (err, doc) ->
        return done "Can't find item: #{err}" if err?
        # when resolving it
        doc.resolve (err, doc) ->
          return done "Can't resolve links: #{err}" if err?
          # then linked items are provided
          assert.equal doc.get('affluents').length, 1
          linked = doc.get('affluents')[0]
          assert.ok item2._id.equals linked._id
          assert.equal linked.get('name'), item2.get('name')
          assert.equal linked.get('end'), item2.get('end')
          assert.equal linked.get('affluents').length, 0
          done()

    it 'should multi-resolve retrieves all properties of all objects', (done) ->
      # given a unresolved items
      Item.where().sort(name:'asc').exec (err, docs) ->
        return done "Can't find item: #{err}" if err?
        # when resolving them
        Item.multiResolve docs, (err, docs) ->
          return done "Can't resolve links: #{err}" if err?
          # then the first item has resolved links
          assert.ok item._id.equals docs[0].get('end')._id
          assert.equal docs[0].get('end').get('name'), item.get('name')
          assert.equal docs[0].get('end').get('end'), item.get('end')
          assert.equal docs[0].get('end').get('affluents')[0], item.get('affluents')[0]
          # then the second item has resolved links
          assert.equal docs[1].get('affluents').length, 1
          linked = docs[1].get('affluents')[0]
          assert.ok item2._id.equals linked._id
          assert.equal linked.get('name'), item2.get('name')
          assert.equal linked.get('end'), item2.get('end')
          assert.equal linked.get('affluents').length, 0
          done()