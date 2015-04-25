through  = require('through2')
gutil    = require('gulp-util')
includer = require('./lib/htmlincluder')

module.exports = (insertText) ->
  'use strict'

  htmlincluder = ->
    self = this
    includer.buildHtml (file) ->
      f = file.file
      f.contents = new Buffer(file.content)
      self.push f
      return
    return

  aggregateFiles = (file, enc, callback) ->
    if file.isNull()
      @push file
      return callback()
    if file.isStream()
      @emit 'error', new (gutil.PluginError)(
        'gulp-htmlincluder',
        'Stream content is not supported'
      )
      return callback()
    if file.isBuffer()
      includer.hashFile file, insertText
    callback()

  includer.initialize()
  through.obj aggregateFiles, htmlincluder
