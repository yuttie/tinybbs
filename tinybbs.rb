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

def search_res(gid,key_url,content,host_name,ip_addr)
  flag_gid = ip_addr[ip_addr.size-2,ip_addr.size].to_i % NUM_GROUPS
  unless key_url.nil? || key_url.empty?
    flag_key = fit_res(key_url,content,host_name,ip_addr)
  else
    if gid == nil
      return 1
    elsif flag_gid.to_i == gid-1
      return 1
    end
  end

  if flag_key == 1
    if gid == nil
      return 1
    elsif flag_gid.to_i == gid-1
      return 1
    end
  end
end

def fit_res(key_url,content,host_name,ip_addr)
  if(key_url =~ /^host_name=/)
    if(Regexp.compile(key_url.sub("host_name=", "")) =~ host_name)
      return 1
    end
  elsif(key_url =~ /^ip_addr=/)
    if(Regexp.compile(key_url.sub("ip_addr=", "")) =~ ip_addr)
      return 1
    end
  else
    if(Regexp.compile(key_url) =~ content)
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
  unless req.query["group_id"].nil? || req.query["group_id"].empty?
    current_gid = req.query["group_id"].to_i
  else
    current_gid = nil
  end
  unless req.query["key"].nil? || req.query["key"].empty?
    key_url = req.query["key"].force_encoding("UTF-8")
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
      <p><input type="submit" value="更新"></p>
      <div id="radio_button">
HTML
  radio = []
  if current_gid == nil
    radio << '<label><input type="radio" name="group_num" value="" checked>all</label>'
  else
    radio << '<label><input type="radio" name="group_num" value="">all</label>'
  end
  for num in 1..NUM_GROUPS do
    if num == current_gid
      radio << "<label><input type=\"radio\" name=\"group_num\" value=#{num} checked>#{num}</label>"
    else
      radio << "<label><input type=\"radio\" name=\"group_num\" value=#{num}>#{num}</label>"
    end
  end
  res.body += radio.join

  if defined?key_url
    res.body += <<HTML
      <label><input type="text" size="30" name="key" value=#{key_url}></label>
HTML
  else
    res.body += <<HTML
      <label><input type="text" size="30" name="key"></label>
HTML
  end

  res.body += <<HTML
    </div>
    </form>
    </div>
    <div class="cl1"></div>
    
    <div>
      <div class="left_view_title">
        <h3>投稿</h3>
      </div>
      <div id="teacher_view">
HTML
  posts = []
  Dir.glob('./content/*').sort.each_with_index {|fp, i|
    host_name, ip_addr = req.peeraddr.values_at(2, 3)
    time = Time.now
    post_id = File.basename(fp)
    time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
    ip_addr = read_file_if_exist("./ip_addr/#{post_id}")
    host_name = read_file_if_exist("./host_name/#{post_id}")
    content = show_spaces(escape(make_links(IO.read("./content/#{post_id}"))))
    
    if(search_res(current_gid,key_url,content,host_name,ip_addr) == 1)
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
    </div>
  </body>
</html>
HTML
}

server.mount_proc('/admin/page') {|req, res|
 group_id = req.query["group_num"]
 keyword = req.query["key"]
 keyword_url = ERB::Util.url_encode(keyword)

 res.set_redirect(WEBrick::HTTPStatus::Found, "/admin?group_id=#{group_id}&key=#{keyword_url}")
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
        <button type="submit">書き込む</button>
      </div>
      <div>
        <textarea name="content" rows="5" cols="40" autofocus required></textarea>
      </div>
    </form>
    <div id="column-container">
      <div class="column">
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
    if(check_group(c_ip_addr,ip_addr) == 1 )
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
      </div>

      <div class="column">
        <div class="center_view_title">
          <h3>全体投稿</h3>
        </div>
        <div class="center_view">
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
