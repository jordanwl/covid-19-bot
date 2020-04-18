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

    # when message is text type
    when Line::Bot::Event::MessageType::Text
      events = client.parse_events_from(body)
      text_recieved = event.message['text'].strip.downcase.gsub('ō', 'o')

      events.each do |event|
        message =
          if text_recieved === 'help'
            {
              type: 'text',
              text: INFO
            }
          elsif PREF_LIST.include?(text_recieved)
            {
              type: 'text',
              text: get_latest_cases(text_recieved)
            }
          else
            {
              type: 'text',
              text: UNKNOWN
            }
          end

        client.reply_message(event['replyToken'], message)
      end

    # when message is location type
    when Line::Bot::Event::MessageType::Location
      coordinates = [event.message['latitude'], event.message['longitude']]
      prefecture = Geocoder.search(coordinates).first.state

      # replace special characters and unnecessary words
      parsed_prefecture = prefecture.downcase.gsub('ō', 'o').split(' ')[0]

      message = {
        type: 'text',
        text: get_latest_cases(parsed_prefecture)
      }

      client.reply_message(event['replyToken'], message)

    # when message is other type
    else
      message = {
              type: 'text',
              text: UNKNOWN
      }

      client.reply_message(event['replyToken'], message)
    end
  end

  "OK"
end

# helper methods
def get_latest_cases(prefecture)
  response = HTTParty.get('https://api.apify.com/v2/key-value-stores/YbboJrL3cgVfkV1am/records/LATEST?disableRedirect=true')
  pref_stats = response["infectedByRegion"].select {|obj| obj["region"].downcase === prefecture }[0]

  <<~HEREDOC
  There are currently #{pref_stats["infectedCount"]} cases of COVID-19 in #{pref_stats["region"]}.

  Source: Ministry of Health, Labour and Welfare (https://www.mhlw.go.jp/index.html)

  -----

  現時点での新型コロナウイルス感染症患者数#{pref_stats["region"]}、#{pref_stats["infectedCount"]} 名

  情報元: 厚生労働省 (https://www.mhlw.go.jp/index.html)
  HEREDOC
end

# constants
INFO = <<~HEREDOC
You can either send me a prefecture (e.g. "Tokyo") or location data in Japan and I will provide \
information on the cases in that area.

-----

都道府県（例：東京都）もしくは国内の位置情報のどちらかを送信してください。
該当地域の症例数など情報をお送りします。
HEREDOC

UNKNOWN = <<~HEREDOC
I'm sorry, I didn't understand your message.
Please try again or text 'help' for more information.

-----

メッセージありがとうございます。

申し訳ございません、入力内容が確認できませんでした。
再度入力内容をご確認ください。
さらに詳しい情報が必要な場合はHelpと送信してください。
HEREDOC

PREF_LIST = [
  'hokkaido',
  'aomori',
  'iwate',
  'miyagi',
  'akita',
  'yamagata',
  'fukushima',
  'ibaraki',
  'tochigi',
  'gunma',
  'saitama',
  'chiba',
  'tokyo',
  'kanagawa',
  'niigata',
  'toyama',
  'ishikawa',
  'fukui',
  'yamanashi',
  'nagano',
  'gifu',
  'shizuoka',
  'aichi',
  'mie',
  'shiga',
  'kyoto',
  'osaka',
  'hyogo',
  'nara',
  'wakayama',
  'tottori',
  'shimane',
  'okayama',
  'hiroshima',
  'yamaguchi',
  'tokushima',
  'kagawa',
  'ehime',
  'kochi',
  'fukuoka',
  'saga',
  'nagasaki',
  'kumamoto',
  'oita',
  'miyazaki',
  'kagoshima',
  'okinawa'
]
