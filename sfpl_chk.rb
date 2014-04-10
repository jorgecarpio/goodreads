# https://www.goodreads.com/api/oauth_example

require 'rubygems'
require 'OAuth'
# require 'hpricot'
# require 'rexml/document'
require 'nokogiri'
require 'table_print'

# Optional
# require 'yaml'

key = 'your_key'
secret = 'your_top_secret'
user_id = 'your_goodreads_user_id'

consumer = OAuth::Consumer.new(key,secret, :site => 'http://www.goodreads.com')

request_token = consumer.get_request_token

# open this URL in the browser and authorize
request_token.authorize_url

access_token = request_token.get_request_token

# request 200 per page
uri = URI.parse "http://www.goodreads.com/review/list?format=xml&v=2&id=#{user_id}&shelf=to-read&sort=title&key=#{key}&per_page=200"

response = Timeout::timeout(10) {Net::HTTP.get(uri) }

# doc = Hpricot.XML(response)

# r = REXML::Document.new(response)

# alternately, use Nokogiri
to_read_xml = Nokogiri::XML(response)

# create array of all the titles
# this was for REXML
# titles = r.get_elements('//title')
titles = to_read_xml.search('title').map(&:text)

# get text from elements in array by
# titles[0].text or some such thing

# Now we want to find if SFPL carries the ebook 

# for 1984 e-book the URL is
# http://sflib1.sfpl.org/search/X?SEARCH=1984&x=-730&y=-163&searchscope=1&p=&m=h&Da=&Db=&SORT=D

# the important thing is the parameter
# &m=h for e-book
# provide the title variable
# sfpl_uri = URI.parse "http://sflib1.sfpl.org/search/X?SEARCH=#{title}&x=-730&y=-163&searchscope=1&p=&m=h&Da=&Db=&SORT=D"
# sfpl_response = Timeout::timeout(10) { Net::HTTP.get(sfpl_uri) }

# testing...
# you want a hash table key/value pairs are Book Title/Result Boolean
ebook_table = Hash.new
for title in titles
  encoded_title = URI::encode title
  sfpl_uri = URI.parse "http://sflib1.sfpl.org/search/X?SEARCH=#{encoded_title}&x=-730&y=-163&searchscope=1&p=&m=h&Da=&Db=&SORT=D"
  sfpl_response = Timeout::timeout(10) { Net::HTTP.get(sfpl_uri) }
  sfpl_doc = Nokogiri::HTML(sfpl_response)
  result = sfpl_doc.css("a[name='anchor_1']")
  # append to ebook_table(title, result.empty?)
  # true means no e-book
  # false means e-book!
  ebook_table[title] = result.empty?
  sleep(1)
end
# buffer error

# Optional: Save hash to yaml
# File.open('ebook_table.yaml', 'w') { |i| i.puts ebook_table.to_yaml }

# Optional: Bring yaml to hash
# ebook_table = YAML::load( File.open('ebook_table.yaml'))

doc = Nokogiri::HTML(sfpl_response)
doc.css("a[name='anchor_1']")
# will return
# [#<Nokogiri::XML::Element:0x3ff5b483b12c name="a" attributes=[#<Nokogiri::XML::Attr:0x3ff5b483b03c name="name" value="anchor_1">]>] 

# if not empty, then we've got a hit.

