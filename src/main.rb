require 'net/http'
require 'json'
require 'date'
require 'time'
require 'dotenv/load'

require_relative 'list_util'
require_relative 'trmnl_sender'

MAX_DATA_POINTS_WITHIN_PAYLOAD_LIMIT = 79

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

  compressed_data_weights = ListUtil.filter_with_end_bias(transformed_data_weights, MAX_DATA_POINTS_WITHIN_PAYLOAD_LIMIT)

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
    :w => compressed_data_weights
  }
end

############# execution #########
date_from = (Date.today - (ENV['LIBRA_WEEKS'].to_i * 7)).strftime('%Y%m%d')
raw_data = get_libra_raw_data(date_from)
data = transform(raw_data)

TrmnlSender.send_to_trmnl(data)
