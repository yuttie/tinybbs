#!/usr/bin/ruby -Ku
# vim: set fileencoding=utf-8:

if RUBY_VERSION >= '1.9'
  Encoding.default_external = Encoding::UTF_8
end

require 'webrick'
require 'uri'

NUM_GROUPS = 21

def mkdir_if_not_exist(dp)
  Dir.mkdir(dp) unless Dir.exist?(dp)
  raise "Couldn't make a directory '#{dp}'." unless Dir.exist?(dp)
end

def read_file_if_exist(fp)
  File.exist?(fp) ? IO.read(fp) : ''
end

def make_links(str)
  str.gsub(URI.regexp, '<a href="\&">\&</a>')
end

def make_res_anchors(str, id_base = "post")
  str.gsub(/(&gt;|＞){1,2}([0-9０-９]+)/) {
    post_id = id_base + $2.tr('０-９', '0-9')
    "<a href=\"##{post_id}\">#{$&}</a>"
  }
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

def check_group(c_ip_addr,ip_addr)
  str_cip = c_ip_addr[c_ip_addr.size-2,c_ip_addr.size]
  str_ip = ip_addr[ip_addr.size-2,ip_addr.size]
  if(str_cip.to_i % NUM_GROUPS == str_ip.to_i % NUM_GROUPS)
    1
  end
end

def search_res(gid,query,content,host_name,ip_addr)
  flag_gid = ip_addr[ip_addr.size-2,ip_addr.size].to_i % NUM_GROUPS
  unless query.nil? || query.empty?
    flag_query = fit_res(query,content,host_name,ip_addr)
  else
    if gid == nil
      return 1
    elsif flag_gid.to_i == gid-1
      return 1
    end
  end

  if flag_query == 1
    if gid == nil
      return 1
    elsif flag_gid.to_i == gid-1
      return 1
    end
  end
end

def fit_res(query,content,host_name,ip_addr)
  if(query =~ /^host=/)
    if(Regexp.compile(query.sub("host=", "")) =~ host_name)
      return 1
    end
  elsif(query =~ /^ip=/)
    if(Regexp.compile(query.sub("ip=", "")) =~ ip_addr)
      return 1
    end
  else
    if(Regexp.compile(query) =~ content)
      return 1
    end
  end
end

mkdir_if_not_exist('./content')
mkdir_if_not_exist('./ip_addr')
mkdir_if_not_exist('./host_name')

server = WEBrick::HTTPServer.new({
  :DocumentRoot => './public',
  :DocumentRootOptions => { :FancyIndexing => false },
  :BindAddress => 'localhost',
  :Port => 8080})
trap("INT") { server.shutdown }

#教員用
server.mount_proc('/admin') {|req, res|
  unless req.query["group"].nil? || req.query["group"].empty?
    current_gid = req.query["group"].to_i
  else
    current_gid = nil
  end
  unless req.query["q"].nil? || req.query["q"].empty?
    query = req.query["q"].force_encoding("UTF-8")
  else
    query = nil
  end

  res.content_type = 'text/html'
  res.body = <<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <link rel="stylesheet" type="text/css" href="/tinybbs.css" />
    <title>Tiny BBS</title>
  </head>
  <body>
    <h1>Tiny BBS</h1>
    <div id="form-container-admin">
      <form method="GET" class="radio_form" action="/admin">
HTML
  radio = []
  if current_gid == nil
    radio << '<label><input type="radio" name="group" value="" checked>All</label>'
  else
    radio << '<label><input type="radio" name="group" value="">All</label>'
  end
  for num in 1..NUM_GROUPS do
    if num == current_gid
      radio << "<label><input type=\"radio\" name=\"group\" value=#{num} checked>#{num}</label>"
    else
      radio << "<label><input type=\"radio\" name=\"group\" value=#{num}>#{num}</label>"
    end
  end
  res.body += '<div><label>Group:</label>' + '<div id="radio_button">' + radio.join + '</div></div>'

  res.body += "<div><label for=\"query-box\">Regexp Query:</label><div><input id=\"query-box\" type=\"text\" name=\"q\" value=#{query || ""}></div></div>"

  res.body += <<HTML
        <div class="form-toolbar">
          <button type="submit">更新</button>
        </div>
      </form>
      <form method="POST" class="text_form" action="/admin/post">
        <div>
          <textarea name="content" rows="5" autofocus required></textarea>
        </div>
        <div class="form-toolbar">
          <button type="submit">書き込む</button>
        </div>
      </form>
    </div>

    <div id="column-container-admin">
      <div class="column-admin">
        <div class="view_title">
          <h3>投稿</h3>
        </div>
        <div class="view">
HTML
  posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    host_name, ip_addr = req.peeraddr.values_at(2, 3)
    time = Time.now
    post_id = File.basename(fp)
    time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
    ip_addr = read_file_if_exist("./ip_addr/#{post_id}")
    host_name = read_file_if_exist("./host_name/#{post_id}")
    content = make_res_anchors(make_links(show_spaces(escape(IO.read("./content/#{post_id}")))))

    if(search_res(current_gid,query,content,host_name,ip_addr) == 1)
      if query && query !~ /^(host_name|ip_addr)=/
        content.gsub!(Regexp.compile(query), '<strong>\0</strong>')
      end
      posts << "<div id=\"post#{i + 1}\" class=\"post\">"\
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
    end
  }
  res.body += posts.reverse.join
  res.body += <<HTML
        </div>
      </div>
    </div>
  </body>
</html>
HTML
}

server.mount_proc('/admin/post') {|req, res|
  host_name, ip_addr = req.peeraddr.values_at(2, 3)
  time = Time.now
  post_id = time.to_i.to_s + time.usec.to_s.rjust(6, '0')
  IO.write('./content/'   + post_id, req.query['content'])
  IO.write('./ip_addr/'   + post_id, ip_addr)
  IO.write('./host_name/' + post_id, host_name)
  res.set_redirect(WEBrick::HTTPStatus::Found, '/admin')
}



#学生用
server.mount_proc('/bbs') {|req, res|
  res.content_type = 'text/html'
  res.body = <<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <link rel="stylesheet" type="text/css" href="/tinybbs.css" />
    <title>Tiny BBS</title>
  </head>
  <body>
    <h1>Tiny BBS</h1>
    <form method="POST" action="/bbs/post">
      <div>
        <textarea name="content" rows="5" autofocus required></textarea>
      </div>
      <div class="form-toolbar">
        <button type="submit">書き込む</button>
      </div>
    </form>
    <div id="column-container">
      <div class="column">
        <div class="view_title">
          <h3>グループ内投稿</h3>
        </div>
        <div class="view">
HTML
  all_posts = []
  posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    c_host_name, c_ip_addr = req.peeraddr.values_at(2, 3)

    #c_ip_addr = "133.5.104.162"
    post_id = File.basename(fp)
    time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
    ip_addr = read_file_if_exist("./ip_addr/#{post_id}")
    host_name = read_file_if_exist("./host_name/#{post_id}")
    content = make_res_anchors(make_links(show_spaces(escape(IO.read("./content/#{post_id}")))), "apost")

    all_posts << "<div id=\"apost#{i + 1}\" class=\"post\">"\
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
    if(check_group(c_ip_addr,ip_addr) == 1 )
      content = make_res_anchors(make_links(show_spaces(escape(IO.read("./content/#{post_id}")))))
      posts << "<div id=\"post#{i + 1}\" class=\"post\">"\
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
    end
  }
  res.body += posts.reverse.join
  res.body += <<HTML
        </div>
      </div>

      <div class="column">
        <div class="view_title">
          <h3>全体投稿</h3>
        </div>
        <div class="view">
HTML
  res.body += all_posts.reverse.join
  res.body += <<HTML
      </div>
    </div>
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
