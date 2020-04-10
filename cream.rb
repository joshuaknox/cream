require 'active_support/all'
require 'colorize'
require 'json'
require 'nokogiri'
require 'typhoeus'
require 'irb'

Econ = JSON.parse(File.read("econ.json"))

now = Time.now
rates = {}
dates = []

times = (1..30).to_a.reverse.map {|x| x.days.ago} << now 

times.each do |time|
	date = time.strftime("%Y-%m-%d")	
	dates << date
	
	rates[date] = {}
	filename = date + ".rates.json" 
	if File.exist?(filename)
		rates[date] = JSON.parse(File.read(filename))
	else
		request = Typhoeus::Request.new("https://www.x-rates.com/historical/?from=USD&amount=1&date=#{date}")
		request.run
		response = request.response
		document = Nokogiri::HTML.parse(response.body)
		table = document.css('.tablesorter.ratesTable')
		cells = []
		table.search('tr').each do |tr|
			cells << tr.search('th, td')
		end
		cells.shift
		cells.each do |cell|
			currency = cell.children[1].attributes["href"].value.last(3)	
			amount = cell.children[1].text.to_f
			rates[date][currency] = amount
		end
		File.write(filename, rates[date].to_json)
	end
end

deltas = {}

world_gdp = Econ.values.reduce(:+)

shifts = {}
Econ.each do |currency, gdp|
	gdp_fraction = (gdp / world_gdp)
	shift = dates.each_cons(2).map do |prior, current|
		if currency == "USD"
			0.0
		else
			delta = rates[current][currency] - rates[prior][currency]
			deltas[currency] = delta
			delta * gdp_fraction
		end
	end
	shifts[currency] = shift
end

dates.each_with_index do |date, i|
	next if i == 0
	total_shift = shifts.values.map { |v| v[i-1] }.reduce(:+)
	if total_shift > 0.0
		puts date.colorize(:green)
	elsif total_shift < 0.0
		puts date.colorize(:red)
	else
		puts date
	end
end
