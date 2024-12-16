require 'net/http'
require 'json'
require 'date'
require 'time'
require 'dotenv/load'

def get_libra_raw_data(since)
  libra_api_key = ENV['LIBRA_API_KEY']
  libra_api_uri = "api.libra-app.eu"
  http = Net::HTTP.new(libra_api_uri, 443)
  #http.set_debug_output($stdout)
  http.use_ssl = true

  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{libra_api_key}"
  }

  path = "/values/weight?from=#{since}"

  puts "Getting weight data from #{libra_api_uri}#{path}"

  request = Net::HTTP::Get.new(path, headers)

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    data = JSON.parse(response.body)
    puts "Response: #{data}"
    return data
  else
    puts "Error: #{response.code} - #{response.message}"
  end
rescue StandardError => e
  puts "Error: #{e.message}"
end

def transform(raw_data)
  puts "Data transformations"
  data_weight_values = raw_data.values[0]

  transformed_data_weights = data_weight_values.map do |entry|
    {:date=> entry["date"][0..9],                 # "2024-12-15T16:22:38.000Z" -> "2024-12-15"
     :weight => entry["weight_trend"].floor(1)    # 82.30899810791016 -> 82.3
    }
  end

  last_entry = data_weight_values.max_by {|entry| entry["date"]}
  last_entry_value = last_entry["weight"].floor(1)

  now = Time.now
  one_week_ago = now - (7 * 24 * 60 * 60)  # 7 days in seconds

  weights_values = data_weight_values.filter { |entry|
    date = Time.parse(entry["date"])
    date >= one_week_ago && date <= now
  }.map { |entry|
    entry["weight"]
  }

  average = (weights_values.sum.to_f / weights_values.size).floor(1)

  {
    :weights => transformed_data_weights,
    :current => last_entry_value,
    :average => average,
    :change => (last_entry_value - average).floor(1),
    :timestamp => DateTime.now
  }
end

def send_to_trmnl(data_payload)
  trmnl_api_key = ENV['TRMNL_API_KEY']
  webhook_id = ENV['TRMNL_PLUGIN_ID']
  trmnl_webhook_url = "https://usetrmnl.com/api/custom_plugins/#{webhook_id}"

  puts('Send data to trmnl webhook')
  uri = URI(trmnl_webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  #http.set_debug_output($stdout)

  headers = {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{trmnl_api_key}"
  }

  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = {merge_variables: data_payload}.to_json

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    current_timestamp = DateTime.now.iso8601
    puts "Tasks sent successfully to TRMNL at #{current_timestamp}"
  else
    puts "Error: #{response.body}"
  end
rescue StandardError => e
  puts e.message
end

############# execution #########

ten_years_ago = (Date.today << (10 * 12)).strftime('%Y%m%d')

raw_data = get_libra_raw_data(ten_years_ago)
data = transform(raw_data)
send_to_trmnl(data)
