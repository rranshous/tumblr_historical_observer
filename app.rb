# GOAL
# watch for new blogs
# scrape / observe the posts for new blogs

require 'uri'
require 'feedjira'
require_relative 'streamworker'

handle 'new-blogs' do |state, event|
  join = lambda { |*args|
    args.map { |arg| arg.gsub(%r{^/*(.*?)/*$}, '\1') }.join("/")
  }
  state[:seen] ||= []
  blog_href = event[:body]['href']
  if blog_href.nil? || blog_href.chomp == ''
    puts "BAD BLOG HREF: #{blog_href}"
    next
  end
  if state[:seen].include? blog_href
    puts "SEEN BLOG: #{blog_href}"
    next
  end
  state[:seen] << blog_href
  puts "BLOG HREF: #{blog_href}"
  last_page = nil
  post_count = 0
  (1..1000).each do |page_number|
    urls = [join.call(blog_href,'/page/',"/#{page_number}/",'rss').to_s]
    puts "URL: #{urls.last}"
    feed = Feedjira::Feed.fetch_and_parse(urls)[urls.first]
    if feed.is_a?(Fixnum)
      puts "BAD FEED: #{feed}"
    else
      if feed.entries.length == 0
        puts "END OF BLOG [#{blog_href}]: #{page_number}"
        break
      end
      feed.entries.each do |entry|
        puts "HANDLING POST [#{post_count+1}]: #{entry.url}"
        post_data = {
          'href' => entry.url,
          'blog' => { 'href' => feed.url },
          'timestamp' => entry.published.iso8601
        }
        puts "EMIT ['tumblr'|'observed_post']: #{post_data}"
        emit 'tumblr', 'observed-post', post_data
        post_count += 1
      end
    end
    last_page = page_number
  end
  emit 'blogs', 'scraped', {
    'href' => blog_href,
    'num_pages_scraped' => last_page,
    'num_posts_observed' => post_count
  }
end

at_exit { puts "ERROR: #{$!}" unless $!.nil? }
