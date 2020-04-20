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
      text_recieved =
        if PREFECTURES.value?(event.message['text'].strip)
          PREFECTURES.key(event.message['text'].strip)
        else
          event.message['text'].strip.downcase.gsub('ō', 'o')
        end

      events.each do |event|
        message =
          if text_recieved === 'help'
            {
              type: 'text',
              text: INFO
            }
          elsif PREFECTURES.key?(text_recieved)
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

      puts coordinates
      puts prefecture
      puts Geocoder.search(coordinates).first
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
  pref_stats = response["infectedByRegion"].select { |obj| obj["region"].downcase.to_sym === prefecture.to_sym }[0]

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

PREFECTURES = {
  hokkaido: '北海道',
  aomori: '青森県',
  iwate: '岩手県',
  miyagi: '宮城県',
  akita: '秋田県',
  yamagata: '山形県',
  fukushima: '福島県',
  ibaraki: '茨城県',
  tochigi: '栃木県',
  gunma: '群馬県',
  saitama: '埼玉県',
  chiba: '千葉県',
  tokyo: '東京都',
  kanagawa: '神奈川県',
  niigata: '新潟県',
  toyama: '富山県',
  ishikawa: '石川県',
  fukui: '福井県',
  yamanashi: '山梨県',
  nagano: '長野県',
  gifu: '岐阜県',
  shizuoka: '静岡県',
  aichi: '愛知県',
  mie: '三重県',
  shiga: '滋賀県',
  kyoto: '京都府',
  osaka: '大阪府',
  hyogo: '兵庫県',
  nara: '奈良県',
  wakayama: '和歌山県',
  tottori: '鳥取県',
  shimane: '島根県',
  okayama: '岡山県',
  hiroshima: '広島県',
  yamaguchi: '山口県',
  tokushima: '徳島県',
  kagawa: '香川県',
  ehime: '愛媛県',
  kochi: '高知県',
  fukuoka: '福岡県',
  saga: '佐賀県',
  nagasaki: '長崎県',
  kumamoto: '熊本県',
  oita: '大分県',
  miyazaki: '宮崎県',
  kagoshima: '鹿児島県',
  okinawa: '沖縄県'
}
