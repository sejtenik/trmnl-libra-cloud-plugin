require 'net/http'
require 'json'
require 'date'
require 'time'
require 'dotenv/load'

TRMNL_PAYLOAD_LIMIT = 2048

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

  transformed_data_weights = data_weight_values
       .group_by { |entry| entry["date"][0..9] }
       .transform_values { |group| group.max_by { |entry| entry["date"] } }
       .values
       .map do |entry|
    [entry["date"][0..9],                 # "2024-12-15T16:22:38.000Z" -> "2024-12-15"
     entry["weight"].round(1),
     entry["weight_trend"].round(1)    # 82.30899810791016 -> 82.3
    ]
  end

  last_entry = data_weight_values.max_by {|entry| entry["date"]}
  last_entry_weight_value = last_entry["weight"].round(1)
  last_entry_trend_value = last_entry["weight_trend"].round(1)

  one_week_ago = (Time.parse(last_entry["date"]) - (7 * 24 * 60 * 60)).to_date # 7 days in seconds

  weights_trend_last_week_value = data_weight_values.filter { |entry|
    date = Time.parse(entry["date"]).to_date
    date > one_week_ago && date < Date.today
  }.map { |entry|
    entry["weight_trend"]
  }.first

  {
    :d => last_entry["date"][0..9],
    :v => last_entry_weight_value,
    :t => last_entry_trend_value,
    :c => (last_entry_trend_value - weights_trend_last_week_value).round(1),
    :w => transformed_data_weights
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
  body = { merge_variables: data_payload }.to_json

  puts body

  if body.bytesize > TRMNL_PAYLOAD_LIMIT
    raise "Request body is too large (#{body.bytesize} bytes, limit: #{TRMNL_PAYLOAD_LIMIT} bytes)"
  else
    puts "Request body size: (#{body.bytesize} bytes)"
  end

  request.body = body


  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    current_timestamp = DateTime.now.iso8601
    puts "Tasks sent successfully to TRMNL at #{current_timestamp}"
  else
    puts "Error: #{response}"
  end
rescue StandardError => e
  puts e.message
end

############# execution #########

date_from = (Date.today - (ENV['LIBRA_WEEKS'].to_i * 7)).strftime('%Y%m%d')

raw_data = get_libra_raw_data(date_from)
data = transform(raw_data)

send_to_trmnl(data)
