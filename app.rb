require 'rubygems'
require 'bundler'
require 'geocoder'
require 'httparty'
require 'line/bot'

Bundler.require

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_id = ENV["LINE_CHANNEL_ID"]
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

post '/callback' do
  body = request.body.read
  signature = request.env['HTTP_X_LINE_SIGNATURE']

  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)

  events.each do |event|
    case event.type
    when Line::Bot::Event::MessageType::Text
      events = client.parse_events_from(body)

      events.each do |event|
        message = {
          type: 'text',
          text: get_latest_cases(event.message['text'])
        }

        client.reply_message(event['replyToken'], message)
      end
    when Line::Bot::Event::MessageType::Location
      message = {
        type: 'text',
        text: [event.message['latitude'], event.message['longitude']]
      }

      client.reply_message(event['replyToken'], message)
    end
  end


  # Don't forget to return a successful response
  "OK"
end

def get_prefecture_from_location(lat, lon)

end

def get_latest_cases(prefecture)
  response = HTTParty.get('https://api.apify.com/v2/key-value-stores/YbboJrL3cgVfkV1am/records/LATEST?disableRedirect=true')

  pref_stats = response["infectedByRegion"].select {|obj| obj["region"].downcase === prefecture.downcase.strip }[0]
  "#{pref_stats["region"]}: #{pref_stats["infectedCount"]}"
end

def reply_content(event, messages)
  res = client.reply_message(
    event['replyToken'],
    messages
  )

  res
end
