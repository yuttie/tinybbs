#!/usr/bin/ruby -Ku
# vim: set fileencoding=utf-8:

if RUBY_VERSION >= '1.9'
  Encoding.default_external = Encoding::UTF_8
end

require 'webrick'
require 'uri'

NUM_GROUPS = 21

class FsDB
  def initialize(db_dir)
    @db_dir = db_dir
    mkdir_if_not_exist("#{@db_dir}/content")
    mkdir_if_not_exist("#{@db_dir}/ip_addr")
    mkdir_if_not_exist("#{@db_dir}/host_name")
  end

  def posts
    Dir.glob("#{@db_dir}/content/*").sort.map.with_index {|fp, i|
      post_id = File.basename(fp)
      time = Time.at(post_id[0...-6].to_i, post_id[-6..-1].to_i)
      ip_addr = read_file_if_exist("#{@db_dir}/ip_addr/#{post_id}")
      host_name = read_file_if_exist("#{@db_dir}/host_name/#{post_id}")
      content = IO.read("#{@db_dir}/content/#{post_id}")

      Post.new(i + 1, time, ip_addr, host_name, content)
    }
  end

  private
  def mkdir_if_not_exist(dp)
    Dir.mkdir(dp) unless Dir.exist?(dp)
    raise "Couldn't make a directory '#{dp}'." unless Dir.exist?(dp)
  end

  def read_file_if_exist(fp)
    File.exist?(fp) ? IO.read(fp) : ''
  end
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

class Post
  attr_accessor :num, :time, :ip_addr, :host_name, :content

  def initialize(num, time, ip_addr, host_name, content)
    @num = num
    @time = time
    @ip_addr = ip_addr
    @host_name = host_name
    @content = content
  end

  def to_html(id_base = 'post')
    escaped_content = make_res_anchors(make_links(show_spaces(escape(@content))), id_base)
    <<-HTML
    <div id="#{id_base}#{@num}" class="post">
      <div class="header">
        <span class="number">#{@num}</span>
        <span class="time">#{@time.strftime('%Y/%m/%d %H:%M:%S')}</span>
        <span class="host">
           <span class="host-name">#{@host_name}</span>
           &nbsp;
           <span class="ip-addr">(#{@ip_addr})</span>
        </span>
      </div>
      <div class="content">#{escaped_content}</div>
    </div>
    HTML
  end
end

class MatchedPost < Post
  def initialize(post, query_str)
    super(post.num, post.time, post.ip_addr, post.host_name, post.content)
    @query = query_str && Regexp.compile(query_str, Regexp::IGNORECASE)
  end

  def to_html(id_base = 'post')
    escaped_content = make_res_anchors(make_links(show_spaces(escape(@content))), id_base)
    escaped_content.gsub!(@query, '<strong>\0</strong>') if @query
    <<-HTML
    <div id="#{id_base}#{@num}" class="post">
      <div class="header">
        <span class="number">#{@num}</span>
        <span class="time">#{@time.strftime('%Y/%m/%d %H:%M:%S')}</span>
        <span class="host">
           <span class="host-name">#{@host_name}</span>
           &nbsp;
           <span class="ip-addr">(#{@ip_addr})</span>
        </span>
      </div>
      <div class="content">#{escaped_content}</div>
    </div>
    HTML
  end
end

def addr_to_group_id(ip_addr)
  (ip_addr.split('.').last.to_i % 100) % NUM_GROUPS + 1
end

def in_group(post, gid)
  if gid
    addr_to_group_id(post.ip_addr) == gid
  else
    true
  end
end

def query_matches(query, post)
  if query
    combined = "ip=#{post.ip_addr}\nhost=#{post.host_name}\nc=#{post.content}"
    Regexp.compile(query, Regexp::IGNORECASE) =~ combined
  else
    true
  end
end

def make_control_form(gid, query)
  radio = []
  if gid == nil
    radio << '<label><input type="radio" name="group" value="" checked>All</label>'
  else
    radio << '<label><input type="radio" name="group" value="">All</label>'
  end
  for num in 1..NUM_GROUPS do
    if num == gid
      radio << "<label><input type=\"radio\" name=\"group\" value=#{num} checked>#{num}</label>"
    else
      radio << "<label><input type=\"radio\" name=\"group\" value=#{num}>#{num}</label>"
    end
  end
  <<-HTML
      <form method="GET" class="radio_form" action="/admin">
        <div>
          <label>Group:</label>
          <div id="radio_button">
#{radio.join}
          </div>
        </div>
        <div>
          <label for="query-box">Regexp Query:</label>
          <div>
            <input id="query-box" type="text" name="q" value="#{query}">
          </div>
        </div>
        <div class="form-toolbar">
          <button type="submit">更新</button>
        </div>
      </form>
  HTML
end

db = FsDB.new('.')

server = WEBrick::HTTPServer.new({
  :DocumentRoot => './public',
  :DocumentRootOptions => { :FancyIndexing => false },
  :BindAddress => 'localhost',
  :Port => 8080})
trap("INT") { server.shutdown }

#教員用
server.mount_proc('/admin') {|req, res|
  current_gid = req.query["group"].to_s.empty? ? nil : req.query["group"].to_i
  query = req.query["q"].to_s.empty? ? nil : req.query["q"].force_encoding("UTF-8")

  selected_posts = db.posts.select {|post|
    in_group(post, current_gid) && query_matches(query, post)
  }.map {|post| MatchedPost.new(post, query) }

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
#{make_control_form(current_gid, query)}
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
#{selected_posts.reverse.map {|post| post.to_html }.join}
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
  ip_addr = req.peeraddr[3]
  gid = addr_to_group_id(ip_addr)

  posts = db.posts
  group_posts = posts.select {|post| in_group(post, gid) }

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
#{group_posts.reverse.map {|post| post.to_html }.join}
        </div>
      </div>

      <div class="column">
        <div class="view_title">
          <h3>全体投稿</h3>
        </div>
        <div class="view">
#{posts.reverse.map {|post| post.to_html("apost") }.join}
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
