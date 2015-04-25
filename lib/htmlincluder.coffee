isWin = /^win/.test(process.platform)

rawFile = (file) ->
  'use strict'
  f =
    name:      ''
    path:      file.path
    content:   file.contents.toString('utf8')
    processed: false
    file:      file
  f.name = if isWin then file.path.split('\\') else file.path.split('/')
  f.name = f.name[f.name.length - 1]
  f

module.exports = ( ->
  'use strict'
  includer    = {}
  wrapFiles   = {}
  insertFiles = {}
  pageFiles   = []
  insertText  = undefined

  processClip = (file) ->
    tmp = undefined
    if file.content.indexOf('<!--#clipbefore') > -1
      file.content = file.content.split(/<!--#clipbefore\s*-->/)
        .splice(1)[0]
        .split('<!--#clipafter')
        .splice(0, 1)[0]
    if file.content.indexOf('<!--#clipbetween') > -1
      tmp = file.content.split(/<!--#clipbetween\s*-->/)
      file.content = tmp[0] + tmp[1].split(/<!--#endclipbetween\s*-->/)[1]
    return

  fixFilePathForOS = (path) ->
    if isWin then path.replace(/\//g, '\\') else path.replace(/\\/g, '/')

  buildPathFromRelativePath = (cdir, fdir) ->
    dir     = undefined
    dirChar = if isWin then '\\' else '/'
    dir     = cdir.split(dirChar)
    fdir    = fixFilePathForOS(fdir)
    dir.pop()
    fdir.split(dirChar).map (e) ->
      if e == '..'
        dir.pop()
      else
        if e != '.' and e != ''
          dir.push e
        else
          undefined
      return
    dir.join dirChar

  processWraps = (file) ->
    aboveWrap  = ''
    topWrap    = ''
    middle     = ''
    bottomWrap = ''
    belowWrap  = ''
    filename   = ''
    fpath      = ''
    fndx       = -1
    lndx       = -1
    didWork    = false
    content    = file.content
    fndx       = content.indexOf('<!--#wrap')
    while fndx > -1
      didWork   = true
      aboveWrap = content.slice(0, fndx)
      middle    = content.slice(fndx)
      lndx      = middle.indexOf('-->') + 3
      filename  = middle.slice(0, lndx).split('"')[1]
      fpath     = buildPathFromRelativePath(file.path, filename)
      middle    = middle.slice(lndx)
      fndx      = middle.indexOf('<!--#endwrap file="' + filename)
      if fndx > -1
        belowWrap = middle.slice(fndx)
        middle    = middle.slice(0, fndx)
        lndx      = belowWrap.indexOf('-->') + 3
        belowWrap = belowWrap.slice(lndx)
      else
        console.log 'ERROR #wrap #endwrap: in file ' + file.path
        return false
      if wrapFiles[fpath]
        processFile wrapFiles[fpath]
        topWrap = wrapFiles[fpath].content
        topWrap = topWrap.split(/<!--#middle\s*-->/)
        if topWrap.length == 2
          bottomWrap = topWrap[1]
          topWrap = topWrap[0]
        else
          console.log 'ERROR #middle: in file ' + file.path
          return false
      else
        console.log 'ERROR no wrapFile: ' + file.path + ' :: ' + filename
        return false
      content = aboveWrap + topWrap + middle + bottomWrap + belowWrap
      fndx = content.indexOf('<!--#wrap')
    file.content = content
    didWork

  processInserts = (file) ->
    didWork  = false
    top      = ''
    bottom   = ''
    filename = ''
    fndx     = -1
    lndx     = -1
    content  = file.content
    fndx     = content.indexOf(insertText)
    while fndx > -1
      didWork  = true
      top      = content.slice(0, fndx)
      content  = content.slice(fndx)
      lndx     = content.indexOf('-->') + 3
      filename = content.slice(0, lndx).split('"')[1]
      bottom   = content.slice(lndx)
      filename = buildPathFromRelativePath(file.path, filename)

      if insertFiles[filename]
        processFile insertFiles[filename]
        content = top + insertFiles[filename].content + bottom
      else
        console.log 'ERROR insert: in file ' + file.path + ' :: ' + filename
        return false

      fndx = content.indexOf(insertText)

    file.content = content
    didWork

  processFile = (file) ->
    changed = true
    while changed and !file.processed
      changed = false
      changed = processWraps(file)
      changed = processInserts(file)
    file.processed = true
    return

  includer.initialize = ->
    wrapFiles   = {}
    insertFiles = {}
    pageFiles   = []
    return

  includer.buildHtml = (callback) ->
    pageFiles.map (file) ->
      processFile file
      if callback
        callback file
      file

  includer.hashFile = (file, insTxt) ->
    f = rawFile(file)
    insertText = if insTxt then '<!--#' + insTxt else '<!--#insert'
    processClip f
    if f.name[0] == '_'
      wrapFiles[f.path] = f
    else if f.name[0] == '-'
      insertFiles[f.path] = f
    else
      pageFiles.push f
    return

  includer
)()
