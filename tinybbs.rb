#!/usr/bin/ruby -Ku
# vim: set fileencoding=utf-8:

if RUBY_VERSION >= '1.9'
  Encoding.default_external = Encoding::UTF_8
end

require 'webrick'


def mkdir_if_not_exist(dp)
  Dir.mkdir(dp) unless Dir.exist?(dp)
  raise "Couldn't make a directory '#{dp}'." unless Dir.exist?(dp)
end

def read_file_if_exist(fp)
  File.exist?(fp) ? IO.read(fp) : ''
end

def escape(string)
  str = string ? string.dup : ""
  str.gsub!(/&/,  '&amp;')
  str.gsub!(/\"/, '&quot;')
  str.gsub!(/>/,  '&gt;')
  str.gsub!(/</,  '&lt;')
  str
end

def show_spaces(string)
  str = string ? string.dup : ""
  str.gsub!(/ /,  '&nbsp;')
  str.gsub!(/\n/, '<br>')
  str
end

mkdir_if_not_exist('./content')
mkdir_if_not_exist('./ip_addr')
mkdir_if_not_exist('./host_name')

server = WEBrick::HTTPServer.new({
  :DocumentRoot => './public',
  :DocumentRootOptions => { :FancyIndexing => false },
  :BindAddress => '133.5.24.189',
  :Port => 8080})
trap("INT") { server.shutdown }

server.mount_proc('/bbs') {|req, res|
  res.content_type = 'text/html'
  res.body = <<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <link rel="stylesheet" type="text/css" href="tinybbs.css" />
    <title>Tiny BBS</title>
  </head>
  <body>
    <h1>Tiny BBS</h1>
    <form method="POST" action="/bbs/post">
      <div>
        <button type="submit">書き込む</button>
      </div>
      <div>
        <textarea name="content" rows="5" cols="40" autofocus required></textarea>
      </div>
    </form>
    <div id="view">
HTML
  posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    post_id = File.basename(fp)
    time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
    ip_addr = read_file_if_exist("./ip_addr/#{post_id}")
    host_name = read_file_if_exist("./host_name/#{post_id}")
    content = show_spaces(escape(IO.read("./content/#{post_id}")))
    posts << '<div class="post">'\
           +   '<div class="header">'\
           +     "<span class=\"number\">#{i + 1}</span>"\
           +     "<span class=\"time\">#{time.strftime('%Y/%m/%d %H:%M:%S')}</span>"\
           +     '<span class="host">'\
           +        "<span class=\"host-name\">#{host_name}</span>"\
           +        '&nbsp;'\
           +        "<span class=\"ip-addr\">(#{ip_addr})</span>"\
           +     '</span>'\
           +   '</div>'\
           +   "<div class=\"content\">#{content}</div>"\
           + '</div>'
  }
  res.body += posts.reverse.join
  res.body += <<HTML
    </div>
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
