
express = require("express")
eco = require("eco")

# https://github.com/npm/nopt
nopt = require("nopt")
Stream = require("stream").Stream
fs = require('fs')
cooked_argv = (a for a in process.argv)
knownOpts =
  is_local: Boolean
  skip_orlando: Boolean
  skip_poetesses: Boolean
  git_commit_hash: [String, null]
  git_branch_name: [String, null]
  port: [Stream, Number]
shortHands =
  faststart: ["--skip_orlando", "--skip_poetesses"]
  #faststart: []

switch process.env.NODE_ENV
  when 'development'
    cooked_argv.push("--faststart")
    cooked_argv.push("--is_local")
    console.log cooked_argv

nopts = nopt(knownOpts, shortHands, cooked_argv, 2)

switch process.env.NODE_ENV
  when 'development'
    console.log nopts

app = express.createServer()

# https://github.com/sstephenson/eco
localOrCDN = (templatePath, isLocal) ->
  template = fs.readFileSync __dirname + templatePath, "utf-8"
  respondDude = (req, res) =>
    res.send(eco.render(template, nopts))
  return respondDude

libxmljs = require "libxmljs"       # https://github.com/polotek/libxmljs
# https://github.com/polotek/libxmljs/wiki/Document
#   NOTE attribute names and tag names are CASE SENSITIVE!!!!?!!???

createSnippetServer = (xmlFileName, uppercase) ->
  if not uppercase? or uppercase
    id_in_case = "ID"
  else
    id_in_case = "id"
  doc = null
  nodes_with_id = []
  elems_by_id = {}
  elems_idx_by_id = {}
  makeXmlDoc = (err, data) ->
    if err
      console.error err
    else
      console.log "parsing #{xmlFileName}..."
      started = new Date().getTime() / 1000
      doc = libxmljs.parseXml(data.toString())
      #doc = new dom().parseFromString(data.toString())
      finished = new Date().getTime() / 1000
      console.log "finished parsing #{xmlFileName} in #{finished - started} sec"

      if true
        console.log "finding IDs in #{xmlFileName}..."
        started = new Date().getTime() / 1000
        # http://stackoverflow.com/questions/4107831/an-xpath-query-that-returns-all-nodes-with-the-id-attribute-set
        nodes_with_id = doc.find('//*[@' + id_in_case + ']')  #  //*[@ID]
        #nodes_with_id = doc.find('//*[@ID!=""]')
        count = nodes_with_id.length
        finished = new Date().getTime() / 1000
        console.log "finished parsing #{xmlFileName} in #{finished - started} sec found: #{count}"

        if true
          started = new Date().getTime() / 1000
          for elem,i in nodes_with_id
            thing = elem.get("@" + id_in_case);
            id = thing.value() # @id  OR  @ID
            #console.log "   ",id,i
            elems_idx_by_id[id] = i
          finished = new Date().getTime() / 1000
          console.log "finished indexing #{xmlFileName} in #{finished - started} sec"

  getSnippetById = (req, res) ->
    if doc
      started = new Date().getTime()
      elem = nodes_with_id[elems_idx_by_id[req.params.id]]
      finished = new Date().getTime()
      sec = (finished - started) / 1000
      if elem?
        snippet = elem.toString()
        res.send(snippet)
      else
        res.send("not found")
    else
      res.send("doc still parsing")
  fs.readFile(xmlFileName, makeXmlDoc)
  return getSnippetById

app.configure ->
  app.use express.logger()
  app.set "views", __dirname + "/views"
  app.use app.router
  app.use("/huviz", express.static(__dirname + '/lib'))
  app.use('/css', express.static(__dirname + '/css'))
  app.use('/jquery-ui-css',
    express.static(__dirname + '/node_modules/jquery-ui/themes/smoothness'))
  # TODO use /jquery-ui/jquery-ui.js instead once "require not found is fixed"
  #   app.use('/jquery-ui',
  #     express.static(__dirname + '/node_modules/jquery-ui'))
  app.use('/data', express.static(__dirname + '/data'))
  app.use('/js', express.static(__dirname + '/js'))
  app.use("/jsoutline", express.static(__dirname + "/node_modules/jsoutline/lib"))
  app.use('/vendor', express.static(__dirname + '/vendor'))
  app.use('/node_modules', express.static(__dirname + '/node_modules'))
  app.use('/mocha', express.static(__dirname + '/node_modules/mocha'))
  app.use('/chai', express.static(__dirname + '/node_modules/chai'))
  app.use('/marked', express.static(__dirname + '/node_modules/marked'))
  app.use('/docs', express.static(__dirname + '/docs'))  
  app.get "/orlonto.html", localOrCDN("/views/orlonto.html.eco", nopts.is_local)
  app.get "/yegodd.html", localOrCDN("/views/yegodd.html.eco", nopts.is_local)
  app.get "/tests", localOrCDN("/views/tests.html.eco", nopts.is_local)
  app.get "/", localOrCDN("/views/huvis.html.eco", nopts.is_local)
  app.use express.static(__dirname + '/images') # for /favicon.ico

port = nopts.port or nopts.argv.remain[0] or process.env.PORT or default_port

# http://regexpal.com/
if not nopts.skip_orlando
  app.get "/snippet/orlando/:id([A-Za-z0-9-_]+)/",
      createSnippetServer("orlando_all_entries_2013-03-04.xml", true)

if not nopts.skip_poetesses
  app.get "/snippet/poetesses/:id([A-Za-z0-9-_]+)/",
      createSnippetServer("poetesses_decomposed.xml", false)

console.log "Starting server on port: #{port} localhost"
app.listen port, 'localhost'
