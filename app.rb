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
      text_received = event.message['text'].strip

      parsed_text = parse_input_text(text_received)

      events.each do |event|
        message =
          if parsed_text === 'help'
            {
              type: 'text',
              text: INFO
            }
          elsif PREFECTURES.key?(parsed_text)
            {
              type: 'text',
              text: get_latest_cases(parsed_text)
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
      prefecture = Geocoder.search(coordinates).first.data&.dig("address", "province")

      # replace special characters and unnecessary words
      parsed_prefecture = prefecture.downcase.gsub('ō', 'o').split(' ')[0].to_sym

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
  pref_stats = response["infectedByRegion"].select { |obj| obj["region"].downcase.to_sym === prefecture }[0]

  <<~HEREDOC
  There are currently #{pref_stats["infectedCount"]} cases of COVID-19 in \
  #{pref_stats["region"]} prefecture.

  Source: Ministry of Health, Labour and Welfare (https://www.mhlw.go.jp/index.html)

  -----

  現時点での新型コロナウイルス感染症患者数#{PREFECTURES[pref_stats["region"].downcase.to_sym]}、\
  #{pref_stats["infectedCount"]} 名

  情報元: 厚生労働省 (https://www.mhlw.go.jp/index.html)
  HEREDOC
end

def parse_input_text(text)
  # check and remove prefectural suffix (-to, -ken, -fu)
  parsed_text = text.split("").slice(0, (text.length - 1).join if SUFFIXES.include?(text.last)

  # return english name if in jp else clean input
  if PREFECTURES.value?(parsed_text)
    PREFECTURES.key(parsed_text)
  else
    text.strip.downcase.gsub('ō', 'o').to_sym
  end
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
さらに詳しい情報が必要な場合はhelpと送信してください。
HEREDOC

SUFFIXES = ['道', '県', '府']

PREFECTURES = {
  hokkaido: '北海',
  aomori: '青森',
  iwate: '岩手',
  miyagi: '宮城',
  akita: '秋田',
  yamagata: '山形',
  fukushima: '福島',
  ibaraki: '茨城',
  tochigi: '栃木',
  gunma: '群馬',
  saitama: '埼玉',
  chiba: '千葉',
  tokyo: '東京都',
  kanagawa: '神奈川',
  niigata: '新潟',
  toyama: '富山',
  ishikawa: '石川',
  fukui: '福井',
  yamanashi: '山梨',
  nagano: '長野',
  gifu: '岐阜',
  shizuoka: '静岡',
  aichi: '愛知',
  mie: '三重',
  shiga: '滋賀',
  kyoto: '京都',
  osaka: '大阪',
  hyogo: '兵庫',
  nara: '奈良',
  wakayama: '和歌山',
  tottori: '鳥取',
  shimane: '島根',
  okayama: '岡山',
  hiroshima: '広島',
  yamaguchi: '山口',
  tokushima: '徳島',
  kagawa: '香川',
  ehime: '愛媛',
  kochi: '高知',
  fukuoka: '福岡',
  saga: '佐賀',
  nagasaki: '長崎',
  kumamoto: '熊本',
  oita: '大分',
  miyazaki: '宮崎',
  kagoshima: '鹿児島',
  okinawa: '沖縄'
}
