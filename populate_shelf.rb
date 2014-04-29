# Ruby script to add books to a (new) bookshelf in goodreads
# Pass in filename to script or barf

# Library for HTTP and URI stuff
require 'net/http'
require 'json'
require 'OAuth'

# goodreads key
key = ARGV[1]
secret = ARGV[2]

# Register app with goodreads
consumer = OAuth::Consumer.new(key,secret, :site => 'http://www.goodreads.com')
request_token = consumer.get_request_token


auth_url = request_token.authorize_url
puts "Open this URL in the browser to authorize"
puts auth_url
blah = $stdin.gets


access_token = request_token.get_access_token

# Param check
if ARGV[0].nil? or ARGV[1].nil? or ARGV[2].nil?
    puts "Missing Parameter(s)"
    puts "First param is text file of books."
    puts "Second is your developer key."
    puts "Third is your secret."
    exit
elsif not File.exist?(ARGV[0])
    puts "Missing file"
    exit
else
    file = ARGV[0]
end

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

# debugging
# puts book_titles
# stopit = $stdin.gets
# end debugging

# 2nd - Use book titles to retrieve list of ISBN numbers
# Google API is
# https://www.googleapis.com/books/v1/volumes?q=search+terms
# returns JSON (use ISBN_13 or 10?)
# {"items": [{"industry identifiers": [
# {"type": "ISBN_13","identifier": "9780141919959"}]}]}

# Persistent connections are not required
isbns = Array.new()

book_titles.each do |i|
    encoded_title = URI::encode i
    uri = URI("https://www.googleapis.com/books/v1/volumes?q=#{encoded_title}&printType=books&fields=items(volumeInfo/industryIdentifiers/type,volumeInfo/industryIdentifiers/identifier)")
    res = Net::HTTP.get(uri) # => String
    parsed = JSON.parse(res) # => Hash
    isbn = nil

    parsed['items'].map { |book| 
        identifiers = book['volume_info'] && book['volume_info']['industryIdentifiers']
        isbn_identifier = idetifiers && identifiers.find{ |prop| 
            ['ISBN_10', 'ISBN_13'].include? prop['type']}['identifier']
    
        isbn_identifier && isbn_identifier['identifier']
    }.compact


    parsed["items"].each do |j| # only continue if isbn is nil
        break if not isbn.nil?
        j["volumeInfo"]["industryIdentifiers"].each do |k|
            next if k["type"] = "OTHER"
                    isbn = k["identifier"]
                    puts isbn
                    isbns.push(isbn)
                    sleep(1)
                    break # K loop
        end 
    end

#     if parsed["items"].first["volumeInfo"]["industryIdentifiers"][0]["type"] = "OTHER"
#         # do stuff
#     end

#     isbn = parsed["items"].first["volumeInfo"]["industryIdentifiers"][1]["identifier"]
#     if isbn.nil?
#         # get the isbn10 number
#         isbn = parsed["items"].first["volumeInfo"]["industryIdentifiers"][0]["identifier"]
#     end
#     isbns.push(isbn)
#     sleep(1)
# end


# 3rd - Use ISBN numbers to retrieve goodreads ID numbers
goodreads_ids = Array.new()

isbns.each do |isbn|
    uri_gr = URI("https://www.goodreads.com/book/isbn_to_id?isbn=#{isbn}&key=#{key}")
    res_gr = Net::HTTP.get(uri_gr)
    goodreads_ids.push(res_gr)
end


# 4th - Create bookshelf on goodreads
res_shelf = access_token.post('/user_shelves.xml', {'user_shelf[name]' => shelf_name})

# 5th - Add books, via their goodreads IDs, to bookshelf
# Takes a comma-separated list of book ids
# and adds them to the shelf name var (name of imported text list of books)

shelves = shelf_name + ',' + 'to-read'
idlist = goodreads_ids.join(',')
res_add = access_token.post('/shelf/add_books_to_shelves.xml', {'bookids' => idlist, 'shelves' => shelf_name})

