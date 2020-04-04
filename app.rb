require 'rubygems'
require 'bundler'
require 'geocoder'
require 'httparty'
require 'line/bot'

Bundler.require

# constants
PREF_LIST = ['hokkaido', 'aomori', 'iwate', 'miyagi', 'akita', 'yamagata', 'fukushima', 'ibaraki', 'tochigi', 'gunma', 'saitama', 'chiba', 'tokyo', 'kanagawa', 'niigata', 'toyama', 'ishikawa', 'fukui', 'yamanashi', 'nagano', 'gifu', 'shizuoka', 'aichi', 'mie', 'shiga', 'kyoto', 'osaka', 'hyōgo', 'nara', 'wakayama', 'tottori', 'shimane', 'okayama', 'hiroshima', 'yamaguchi', 'tokushima', 'kagawa', 'ehime', 'kochi', 'fukuoka', 'saga', 'nagasaki', 'kumamoto', 'oita', 'miyazaki', 'kagoshima', 'okinawa']

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

    # when message is text type
    when Line::Bot::Event::MessageType::Text
      events = client.parse_events_from(body)

      events.each do |event|
        message =
          if event.message['text'] === 'help'
            {
              type: 'text',
              text: 'You can either send me a prefecture (e.g. "Tokyo") or location data and I will provide information on the cases in that area.'
            }
          elsif PREF_LIST.include?(event.message['text'])
            {
              type: 'text',
              text: get_latest_cases(event.message['text'])
            }
          else
            {
              type: 'text',
              text: "I'm sorry, I didn't understand your message. Please try again."
            }
          end

        client.reply_message(event['replyToken'], message)
      end

    # when message is location type
    when Line::Bot::Event::MessageType::Location
      coordinates = [event.message['latitude'], event.message['longitude']]
      prefecture = Geocoder.search(coordinates).first.state
      message = {
        type: 'text',
        text: get_latest_cases(prefecture)
      }

      client.reply_message(event['replyToken'], message)
    end
  end

  "OK"
end

# helper methods
def get_latest_cases(prefecture)
  response = HTTParty.get('https://api.apify.com/v2/key-value-stores/YbboJrL3cgVfkV1am/records/LATEST?disableRedirect=true')

  pref_stats = response["infectedByRegion"].select {|obj| obj["region"].downcase === prefecture.downcase.strip }[0]
  "#{pref_stats["region"]}: #{pref_stats["infectedCount"]}"
end
