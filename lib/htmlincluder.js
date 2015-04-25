var isWin = /^win/.test(process.platform);

function rawFile(file) {
  'use strict';
  var f = {
    name: '',
    path: file.path,
    content: file.contents.toString('utf8'),
    processed: false,
    file: file
  };

  f.name = (isWin) ? file.path.split('\\') : file.path.split('/');
  f.name = f.name[f.name.length-1];

  return f;
}

module.exports = (function htmlIncluder() {
  'use strict';
  var includer = {};
  var wrapFiles = {};
  var insertFiles = {};
  var pageFiles = [];
  var insertText;

  function processClip(file) {
    var tmp;

    if(file.content.indexOf('<!--#clipbefore') > -1) {
      file.content = file.content
                       .split(/<!--#clipbefore\s*-->/)
                       .splice(1)[0]
                       .split('<!--#clipafter')
                       .splice(0,1)[0];
    }

    if(file.content.indexOf('<!--#clipbetween') > -1) {
      tmp = file.content
              .split(/<!--#clipbetween\s*-->/);

      file.content = tmp[0] + tmp[1].split(/<!--#endclipbetween\s*-->/)[1];
    }
  }

  function fixFilePathForOS(path) {
    return (isWin) ? path.replace(/\//g, '\\') : path.replace(/\\/g, '/');
  }

  function buildPathFromRelativePath(cdir, fdir) {
    var dir;
    var dirChar = (isWin) ? '\\' : '/';

    dir = cdir.split(dirChar);
    fdir = fixFilePathForOS(fdir);
    dir.pop();

    fdir.split(dirChar)
      .map(function(e) {
        if (e === '..') {
          dir.pop();
        } else {
          if (e !== '.' && e !== '') {
            dir.push(e);
          } else {
            void 0;
          }
        }
      });

    return dir.join(dirChar);
  }

  function processWraps(file) {
    var aboveWrap  = '';
    var topWrap    = '';
    var middle     = '';
    var bottomWrap = '';
    var belowWrap  = '';
    var filename   = '';
    var fpath      = '';
    var fndx       = -1;
    var lndx       = -1;
    var didWork    = false;
    var content    = file.content;

    fndx = content.indexOf('<!--#wrap');
    while(fndx > -1) {
      didWork = true;
      aboveWrap = content.slice(0, fndx);
      middle = content.slice(fndx);
      lndx = middle.indexOf('-->')+3;

      filename = middle.slice(0, lndx).split('"')[1];
      fpath = buildPathFromRelativePath(file.path, filename);

      middle = middle.slice(lndx);
      fndx =  middle.indexOf('<!--#endwrap file="'+ filename);

      if(fndx > -1) {
        belowWrap = middle.slice(fndx);
        middle = middle.slice(0,fndx);
        lndx = belowWrap.indexOf('-->')+3;
        belowWrap = belowWrap.slice(lndx);
      }
      else {
        console.log('ERROR in file ' + file.path + ': <!--#wrap . . . --> with no <!--#endwrap . . . -->');
        return false;
      }

      if(wrapFiles[fpath]) {
        processFile(wrapFiles[fpath]);
        topWrap = wrapFiles[fpath].content;
        topWrap = topWrap.split(/<!--#middle\s*-->/);
        if(topWrap.length === 2) {
          bottomWrap = topWrap[1];
          topWrap = topWrap[0];
        }
        else {
          console.log('ERROR in file ' + file.path + ': wrap file has no <!--#middle--> or more than one <!--#middle--> tags');
          return false;
        }
      }
      else {
        console.log('ERROR in file ' + file.path + ': no wrapFile by the name `' + filename + '`');
        return false;
      }
      content = aboveWrap + topWrap + middle + bottomWrap + belowWrap;
      fndx = content.indexOf('<!--#wrap');
    }
    file.content = content;
    return didWork;
  }

  function processInserts(file) {
    var didWork  = false;
    var top      = '';
    var bottom   = '';
    var filename = '';
    var fndx     = -1;
    var lndx     = -1;
    var content  = file.content;

    fndx = content.indexOf(insertText);
    while(fndx > -1) {
      didWork = true;
      top = content.slice(0,fndx);
      content = content.slice(fndx);
      lndx = content.indexOf('-->') + 3;

      filename = content.slice(0, lndx).split('"')[1];
      bottom = content.slice(lndx);
      filename = buildPathFromRelativePath(file.path, filename);

      if(insertFiles[filename]) {
        processFile(insertFiles[filename]);
        content = top + insertFiles[filename].content + bottom;
      }
      else {
        console.log('ERROR in file ' + file.path + ': insert file `' + filename + '` does not exist');
        return false;
      }

      fndx = content.indexOf(insertText);
    }

    file.content = content;
    return didWork;
  }

  function processFile(file) {
    var changed = true;

    while(changed && !file.processed) {
      changed = false;
      changed = processWraps(file);
      changed = processInserts(file);
    }
    file.processed = true;
  }

  includer.initialize = function initialize() {
    wrapFiles = {};
    insertFiles = {};
    pageFiles = [];
  };

  includer.buildHtml = function buildHtml(callback) {
    return pageFiles.map(function(file) {
      processFile(file);

      if(callback) {
        callback(file);
      }

      return file;
    });
  };

  includer.hashFile = function hashFile(file, insTxt) {
    var f = rawFile(file);
    insertText = (insTxt) ? '<!--#' + insTxt : '<!--#insert';
    processClip(f);

    if(f.name[0] === '_') {
      wrapFiles[f.path] = f;
    } else if (f.name[0] === '-') {
      insertFiles[f.path] = f;
    } else {
      pageFiles.push(f);
    }
  };

  return includer;
})();
