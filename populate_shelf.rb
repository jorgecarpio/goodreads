# Ruby script to add books to a (new) bookshelf in goodreads
# Pass in filename to script or barf

# Library for HTTP and URI stuff
require 'net/http'
require 'json'
require 'OAuth'
require 'andand'

# goodreads key
key = ARGV[1]
secret = ARGV[2]

# Param check
if ARGV[0].nil? or ARGV[1].nil? or ARGV[2].nil?
    puts "Missing Parameter(s)"
    puts "First param is text file of books."
    puts "Second is your developer key."
    puts "Third is your secret."
    exit
end

while not File.exist?(ARGV[0]) do
    puts "Hello.  I can't locate #{ARGV[0]}"
    puts "Please provide the location of your text list of books."
    puts "e.g. /home/user/mylist.txt"
    puts "Here is a list of files in this folder:"
    puts Dir["*.*"]
    ARGV[0] = $stdin.gets
end

file = ARGV[0]

# Register app with goodreads
consumer = OAuth::Consumer.new(key,secret, :site => 'http://www.goodreads.com')
request_token = consumer.get_request_token


auth_url = request_token.authorize_url
puts "Open this URL in the browser to authorize"
puts auth_url
blah = $stdin.gets


access_token = request_token.get_access_token




# parse filename to use as bookshelf name
shelf_name = File.basename(file, '.txt')

# Steps
# 1st - Read in text file of books
# NOTE: Will need to get author, otherwise results will be too broad
book_titles = Array.new

f = File.open(file, 'r')
f.each_line do |line|
    book_titles.push line
end
f.close

# 2nd - Use book titles to retrieve list of ISBN numbers
# Google API is
# https://www.googleapis.com/books/v1/volumes?q=search+terms
# returns JSON (use ISBN_13 or 10?)
# {"items": [{"industry identifiers": [
# {"type": "ISBN_13","identifier": "9780141919959"}]}]}

# Persistent connections are not required
isbns = Array.new()
missing = Array.new()

book_titles.each do |i|
    if not i.ascii_only?
        i.force_encoding('UTF-8')
    end
    encoded_title = URI::encode i
    uri = URI("https://www.googleapis.com/books/v1/volumes?q=#{encoded_title}&printType=books&fields=items(volumeInfo/industryIdentifiers/type,volumeInfo/industryIdentifiers/identifier,volumeInfo/title)")
    res = Net::HTTP.get(uri) # => String
    parsed = JSON.parse(res) # => Hash
    isbn = parsed['items'].andand.first['volumeInfo'].andand['industryIdentifiers'].andand.find{ |prop| ['ISBN_10', 'ISBN_13'].include? prop['type']}.andand['identifier']
    if not isbn.nil?
        isbns.push isbn
    else
        puts "ISBN for #{i} not found"
        missing.push i
    end
    sleep 3
end

# 3rd - Use ISBN numbers to retrieve goodreads ID numbers
# goodreads_ids = Array.new()

# isbns.each do |isbn|
#     uri_gr = URI("https://www.goodreads.com/book/isbn_to_id?isbn=#{isbn}&key=#{key}")
#     res_gr = Net::HTTP.get(uri_gr)
#     goodreads_ids.push(res_gr)
# end

def convert_isbn_to_goodreads_id(isbn_array)
    goodreads_ids = isbn_array.map { |isbn|
        Net::HTTP.get("https://www.goodreads.com/book/isbn_to_id?isbn=#{isbn}&key=#{key}")
    }
    return goodreads_ids
end

goodreads_ids = convert_isbn_to_goodreads_id(isbns)

# 4th - Create bookshelf on goodreads
res_shelf = access_token.post('/user_shelves.xml', {'user_shelf[name]' => shelf_name})

# 5th - Add books, via their goodreads IDs, to bookshelf
# Takes a comma-separated list of book ids
# and adds them to the shelf name var (name of imported text list of books)

shelves = shelf_name + ',' + 'to-read'
idlist = goodreads_ids.join(',')
res_add = access_token.post('/shelf/add_books_to_shelves.xml', {'bookids' => idlist, 'shelves' => shelves})
puts 'Add these manually to GoodReads'
puts missing
