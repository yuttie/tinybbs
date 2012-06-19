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

server.mount_proc('/bbs') {|req, res|
  res.body = <<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
  </head>
  <body>
    <h1>Tiny BBS</h1>
    <form method="POST" action="/bbs/post">
      <textarea name="content"></textarea>
      <button type="submit">書き込む</button>
    </form>
HTML
  posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    fn = File.basename(fp)
    time = Time.at(fn[0...-6].to_i, fn[-6..-1].to_i)
    content = IO.read(fp).gsub(/</, '&lt;')\
                         .gsub(/>/, '&gt;')\
                         .gsub(/ /, '&nbsp;')\
                         .gsub(/\n/, '<br>')
    posts << "<p>" + "<span>#{i + 1}&nbsp;:&nbsp;</span><span>#{time}</span>" + "<p>#{content}</p>" + "</p><hr>"
  }
  res.body += posts.reverse.join
  res.body += <<HTML
  </body>
</html>
HTML
}
server.mount_proc('/bbs/post') {|req, res|
  host_name, ip_addr = req.peeraddr.values_at(2, 3)
  time = Time.now
  post_id = time.to_i.to_s + time.usec.to_s.rjust(6, '0')
  IO.write('./content/'   + post_id, req.query['content'])
  IO.write('./ip_addr/'   + post_id, ip_addr)
  IO.write('./host_name/' + post_id, host_name)
  res.set_redirect(WEBrick::HTTPStatus::Found, '/bbs')
}
server.start
