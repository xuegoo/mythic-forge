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

async = require 'async'
fs = require 'fs'
pathUtils = require 'path'
fsExtra = require 'fs-extra'
FSItem = require '../main/model/FSItem'
utils = require '../main/utils'
assert = require('chai').assert
service = require('../main/service/AuthoringService').get()

root = utils.confKey 'game.source'

describe 'AuthoringService tests', -> 

  before (done) ->
    # given a clean game source
    fsExtra.remove root, ->
      fsExtra.mkdir root, (err) ->
        throw new Error err if err?
        done()

  it 'should file be created', (done) -> 
    # given a new file
    item = new FSItem "file.txt", false
    # when saving it 
    service.save item, (err, saved) ->
      throw new Error "Cannot save file: #{err}" if err?
      # then the file was saved
      assert.ok item.equals saved
      fs.exists pathUtils.join(root, item.path), (exists) ->
        assert.ok exists, "file #{item.path} wasn't created"
        done()

  it 'should folder be created', (done) -> 
    # given a new file
    item = new FSItem "folder", true
    # when saving it 
    service.save item, (err, saved) ->
      throw new Error "Cannot save folder: #{err}" if err?
      # then the file was saved
      assert.ok item.equals saved
      fs.exists pathUtils.join(root, item.path), (exists) ->
        assert.ok exists, "folder #{item.path} wasn't created"
        done()

  describe 'given an non-empty root', ->
    content = [
      new FSItem 'file1.txt', false
      new FSItem 'file2.txt', false
      new FSItem 'folder', true
    ]
    before (done) ->
      # given a clean game source
      fsExtra.remove root, ->
        # and some file in it
        async.forEach ['file1.txt', 'file2.txt', 'folder/file3.txt', 'folder/file4.txt'], (file, next) ->
          file = pathUtils.join root, file
          fsExtra.mkdir pathUtils.dirname(file), (err) ->
            return next err if err?
            fs.writeFile file, '', next
        , done

    it 'should root retrieve populated root folder', (done) ->
      # when retrieving root folder
      service.readRoot (err, folder) ->
        throw new Error "Cannot retrieve root folder: #{err}" if err?
        # then all awaited subitems are present.
        assert.equal folder.content.length, content.length
        for file in content
          found = false
          for result in folder.content when result.equals file
            found = true
            break
          assert.isTrue found, "file #{file.path} was not read"
        done()

  describe 'given an existing file', ->
    file = null

    before (done) ->
      fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
        throw new Error err if err?
        file = new FSItem 'folder/image1.png', false
        file.content = data
        service.save file, (err, saved) ->
          throw new Error err if err?
          file = saved
          done()

    it 'should file content be read', (done) -> 
      file.content = null
      # when reading the file
      service.read file, (err, read) ->
        throw new Error "Cannot read file: #{err}" if err?
        # then read data is correct
        fs.readFile './hyperion/src/test/fixtures/image1.png', (err, data) ->
          throw new Error err if err?
          assert.equal read.content, data.toString('base64')
          done()
        
    it 'should file content be updated', (done) -> 
      # given a binary content
      fs.readFile './hyperion/src/test/fixtures/image2.png', (err, data) ->
        throw new Error err if err?
        file.content = data
        # when saving it 
        service.save file, (err, saved) ->
          throw new Error "Cannot save existing file: #{err}" if err?
          # then the file was saved
          assert.ok file.equals saved
          assert.equal saved.content, data.toString('base64'),
          # then the saved content is equals
          fs.readFile pathUtils.join(root, saved.path), (err, readData) ->
            throw new Error err if err?
            assert.equal readData.toString('base64'), data.toString('base64')
            done()

    it 'should file be removed', (done) -> 
      # when removing the file
      service.remove file, (err, removed) ->
        throw new Error "Cannot remove file: #{err}" if err?
        # then the file was removed
        assert.ok file.equals removed
        fs.exists pathUtils.join(root, file.path), (exists) ->
          assert.isFalse exists, "file #{file.path} wasn't removed"
          done()  

  describe 'given an existing folder', ->
    folder = null
    files = []

    before (done) ->
      folder = new FSItem 'folder/folder2', true
      service.save folder, (err, saved) ->
        throw new Error err if err?
        folder = saved
        async.forEach ['file1.txt', 'file2.txt'], (file, next) ->
          item = new FSItem pathUtils.join(folder.path, file), false
          files.push item
          service.save item, next
        , (err) ->
          throw new Error err if err?
          done()

    it 'should folder content be read', (done) -> 
      folder.content = null
      # when reading the folder
      service.read folder, (err, read) ->
        throw new Error "Cannot read folder: #{err}" if err?
        # then read data is correct
        assert.equal read.content.length, files.length
        for file in read.content
          found = false
          for content in read.content when content.equals file
            found = true
            break
          assert.isTrue found, "file #{file.path} was not read"
        done()
    
    it 'should folder be removed', (done) -> 
      # when removing the folder
      service.remove folder, (err, removed) ->
        throw new Error "Cannot remove folder: #{err}" if err?
        # then the file was removed
        assert.ok folder.equals removed
        fs.exists pathUtils.join(root, folder.path), (exists) ->
          assert.isFalse exists, "folder #{folder.path} wasn't removed"
          done()