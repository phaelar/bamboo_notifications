require 'telegram/bot'


token = "146810656:AAFcEAQ2yHJkC0jVQ2qvJ9ptvv2Th1uP7Rw"

Telegram::Bot::Client.run(token) do |bot|
  p 'in'
  bot.listen do |message|
    p 'hi'
    p message
    # case message.text
    # when '/start'
    #   bot.api.send_message(chat_id: message.chat.id, text: "Hello, #{message.from.first_name}")
    # when '/stop'
    #   bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    # end
    # bot.api.send_message(chat_id:"@bgp_update", text:"test")
  end
end
