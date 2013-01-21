#!/usr/bin/ruby -Ku
# vim: set fileencoding=utf-8:

if RUBY_VERSION >= '1.9'
  Encoding.default_external = Encoding::UTF_8
end

require 'webrick'
require 'uri'

$g_id = 21
$teacher_id = 0
$keyword = ""

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
  if(str_cip.to_i % $g_id == str_ip.to_i % $g_id)
    1
  end
end

def search_res(content,search_word)
  str = search_word.split(" ")
  str.each {|word|
    if(word == "【.*】")
      p "******Success*****\n"
      if(content =~ /^word/)
        1
        break
      end
    end
  }
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
  p req.query
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
    <div class="form">
    <form method="POST" class="text_form" action="/admin/post">
      <div>
        <button type="submit">書き込む</button>
      </div>
      <div>
        <textarea name="content" rows="5" cols="40" autofocus required></textarea>
      </div>
    </form>
    </div>
    <div class="form">
    <form method="post" class="radio_form" action="/admin/page">
      <p><input type="submit" value="決定"></p>
      <div id="radio_button">
HTML
  radio = []
  for num in 0..$g_id-1 do
    radio << "<label><input type=\"radio\" name=\"group_num\" value=#{num}>#{num}</label>"
  end
  res.body += radio.reverse.join
  res.body += <<HTML
    </div>
    </form>
    </div>
    <div class="cl1"></div>

    <form method="POST" class="tag_form" action="/admin/search">
      <div>
        <input type="text" size="30" name="key">
      </div>
      <div>
        <input type="submit" value="検索">
      </div>
    </form>
    
    <div class="left_view_title">
      <h3>全体投稿</h3>
    </div>
    <div class="left_view">
HTML
  all_posts = []
  posts = []
  search_posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    post_id = File.basename(fp)
    time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
    ip_addr = read_file_if_exist("./ip_addr/#{post_id}")
    host_name = read_file_if_exist("./host_name/#{post_id}")
    content = show_spaces(escape(make_links(IO.read("./content/#{post_id}"))))
    
    all_posts << '<div class="post">'\
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
    if(ip_addr[ip_addr.size-2,ip_addr.size].to_i % $g_id == $teacher_id.to_i)
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
    end
    if(search_res(content,$keyword) == 1)
      search_posts << '<div class="post">'\
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
  res.body += all_posts.reverse.join
  res.body += <<HTML
    </div>
    
    <div class="center_view_title">
      <h3>グループ内投稿</h3>
    </div>
    <div class="center_view">
HTML
  res.body += posts.reverse.join
  res.body += <<HTML
  </div>

  <div class="right_view_title">
    <h3>検索ヒット投稿</h3>
  </div>
  <div class="right_view">
HTML
  res.body += search_posts.reverse.join
  res.body += <<HTML
  </div>
  </body>
</html>
HTML
}

server.mount_proc('/admin/page') {|req, res|
 $teacher_id = req.query["group_num"]
 res.set_redirect(WEBrick::HTTPStatus::Found, '/admin')
}

server.mount_proc('/admin/search') {|req, res|
  $keyword = req.query["key"]
  res.set_redirect(WEBrick::HTTPStatus::Found, '/admin')
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
    <div class="left_view_title">
      <h3>グループ内投稿</h3>
    </div>
    <div class="left_view">
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
    content = show_spaces(escape(make_links(IO.read("./content/#{post_id}"))))
    
    all_posts << '<div class="post">'\
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
    if(check_group(c_ip_addr,ip_addr) == 1)
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
    end
  }
  res.body += posts.reverse.join
  res.body += <<HTML
    </div>
    <div class="center_view_title">
      <h3>全体投稿</h3>
    </div>
    <div class="center_view">
HTML
  res.body += all_posts.reverse.join
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
