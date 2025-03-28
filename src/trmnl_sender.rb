class TrmnlSender
  TRMNL_PAYLOAD_LIMIT = 2048

  def self.send_to_trmnl(data_payload)
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

end