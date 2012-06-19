#!/usr/bin/ruby -Ku

require 'webrick'


class TinyBBS < WEBrick::HTTPServlet::AbstractServlet
end

server = WEBrick::HTTPServer.new({
  :DocumentRoot => './public',
  :DocumentRootOptions => { :FancyIndexing => false },
  #:BindAddress => '127.0.0.1',
  :BindAddress => '133.5.24.189',
  :Port => 8080})
trap("INT") { server.shutdown }

server.mount_proc('/') {|req, res|
  res.body = <<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
  </head>
  <body>
    <h1>Tiny BBS</h1>
    <form method="POST" action="/post">
      <textarea name="content"></textarea>
      <button type="submit">書き込む</button>
    </form>
HTML
  posts = []
  Dir.glob('./data/*').sort.each_with_index {|fp, i|
    time_str = Time.at(File.basename(fp).to_i).to_s
    content = IO.read(fp)
    posts << "<p>" + "<span>#{(i + 1).to_s}&nbsp;:&nbsp;</span><span>#{time_str}</span>" + "<p>#{content}</p>" + "</p><hr>"
  }
  res.body += posts.reverse.join
  res.body += <<HTML
  </body>
</html>
HTML
}
server.mount_proc('/post') {|req, res|
  IO.write('./data/' + Time.now.to_i.to_s, req.query['content'])
  res.set_redirect(WEBrick::HTTPStatus::Found, '/')
}
server.start
