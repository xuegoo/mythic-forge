Item = require '../main/model/Item'
ItemType = require '../main/model/ItemType'

item1 = null
item2 = null
item3 = null
type = null
module.exports = 
  setUp: (end) ->
    # empty items and types.
    Item.collection.drop -> ItemType.collection.drop -> end()

  'should type be created': (test) -> 
    # given a new ItemType
    type = new ItemType()
    name = 'montain'
    type.set 'name', name

    # when saving it
    type.save (err, saved) ->
      if err? 
        test.fail "Can't save type: #{err}"
        return test.done()

      # then it is in mongo
      ItemType.find {}, (err, types) ->
        # then it's the only one document
        test.equal types.length, 1
        # then it's values were saved
        test.equal name, types[0].get 'name'
        test.done()

  'given a type with a property': 
    setUp: (end) ->
      # creates a type with a property color which is a string.
      type = new ItemType()
      type.set 'name', 'river'
      type.setProperty 'color', 'string', 'blue'
      type.save (err, saved) -> 
        type = saved
        end()

    tearDown: (end) ->
      # removes the type at the end.
      ItemType.collection.drop -> Item.collection.drop -> end()

    'should type be removed': (test) ->
      # when removing an item
      type.remove ->

      # then it's in mongo anymore
      ItemType.find {}, (err, types) ->
        test.equal types.length, 0
        test.done()

    'should type properties be created': (test) ->
      # when adding a property
      type.setProperty 'depth', 'integer', 10
      type.save ->

        ItemType.find {}, (err, types) ->
          # then it's the only one document
          test.equal types.length, 1
          # then only the relevant values were modified
          test.equal 'river', types[0].get 'name'
          test.ok 'depth' of types[0].get('properties'), 'no depth in properties'
          test.equal 'integer',  types[0].get('properties').depth?.type
          test.equal 10, types[0].get('properties').depth?.def
          test.done()

    'should type properties be updated': (test) ->
      test.ok 'color' of type.get('properties'), 'no color in properties'
      test.equal 'string',  type.get('properties').color?.type
      test.equal 'blue',  type.get('properties').color?.def

      # when updating a property 
      type.setProperty 'color', 'integer', 10
      type.save (err, saved) ->

        # then the property was updated
        test.equal 'integer',  saved.get('properties').depth?.type
        test.equal 10,  saved.get('properties').depth?.def
        test.done()

    'should type properties be removed': (test) ->
      # when removing a property
      type.unsetProperty 'color'
      type.save (err, saved) ->
        if err? 
          test.fail "Can't save item: #{err}"
          return test.done()

        # then the property was removed
        test.ok not ('color' of saved.get('properties')), 'color still in properties'
        test.done()

    'should unknown type properties fail on remove': (test) ->
      try 
        # when removing an unknown property
        type.unsetProperty 'unknown'
        test.fail 'Error must be raised when removing unknwown property'
      catch err
        # then an error is thrown
        test.equal 'Unknown property unknown for item type river', err?.message
      test.done()

  'given a type and some items': 
    setUp: (end) ->
      # creates a type with a string property 'color' and an array property 'affluent'.
      type = new ItemType()
      type.name = 'river'
      type.setProperty 'color', 'string', 'blue'
      type.setProperty 'affluent', 'array', 'Item'
      type.save (err, saved) -> 
        type = saved
        # creates three items of this type.
        item1 = new Item()
        item1.set 'typeId', type._id
        item1.save ->
          item2 = new Item()
          item2.set 'typeId', type._id
          item2.save ->
            item3 = new Item()
            item3.set 'typeId', type._id
            item3.save ->
              end()

    'should existing items be updated when setting a type property': (test) ->
      # when setting a property to a type
      defaultDepth = 30
      type.setProperty 'depth', 'integer', defaultDepth
      type.save (err) -> 
        block = ->
          Item.find {typeId: type._id}, (err, items) ->
            for item in items
              test.equal defaultDepth, item.get 'depth'
            test.done()
        setTimeout block, 50

    'should existing items be updated when removing a type property': (test) ->
      # when setting a property to a type
      defaultDepth = 30
      type.unsetProperty 'color'
      type.save (err) -> 
        block = ->
          Item.find {typeId: type._id}, (err, items) ->
            for item in items
              test.ok undefined is item.get('color'), 'color still present'
            test.done()
        setTimeout block, 50