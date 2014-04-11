# Ruby script to add books to a (new) bookshelf in goodreads
# Pass in filename to script or barf

# Library for HTTP and URI stuff
require 'rubygems'
require 'net/http'
require 'json'

# goodreads key
key = 'yourkey'

# Param check
if ARGV[0].nil?
    puts "Missing Parameter"
    exit
elsif not File.exist?(ARGV[0])
    puts "Missing file"
    exit
else
    $file = ARGV[0]
end

# parse filename to use as bookshelf name
$shelf_name = File.basename($file, ".txt")

# Steps
# 1st - Read in text file of books
# NOTE: Will need to get author, otherwise results will be too broad
book_titles = Array.new

f = File.open($file, "r")
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

book_titles.each do |i|
    encoded_title = URI::encode i
    uri = URI("https://www.googleapis.com/books/v1/volumes?q=#{encoded_title}")
    # need author, too
    # ?q=#{i}+inauthor:#{author}
    res = Net::HTTP.get(uri) # => String
    parsed = JSON.parse(res) # => Hash
    # Brittle code ahead
    isbn = parsed["items"].first["volumeInfo"]["industryIdentifiers"][1]["identifier"]
    if isbn.nil?
        # get the isbn10 number
        isbn = parsed["items"].first["volumeInfo"]["industryIdentifiers"][0]["identifier"]
    end
    isbns.push(isbn)
    sleep(1)
end

puts isbns
# 3rd - Use ISBN numbers to retrieve goodreads ID numbers
# isbns.each do |k|
    # missing stuff
    # goodreads api example: https://www.goodreads.com/book/isbn_to_id?isbn=&key=#{key}
# end
# 4th - Create bookshelf on goodreads

# 5th - Add books, via their goodreads IDs, to bookshelf

# 6th - Verify
