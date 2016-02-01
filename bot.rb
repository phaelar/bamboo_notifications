require 'telegram/bot'
require 'httparty'
require 'uri'
require 'nokogiri'
require 'rufus-scheduler'
require 'yaml'

config = YAML.load_file('secrets.yml')

$token = config["TAPI_TOKEN"]
$channel_id = config["CHANNEL"]
authinfo = {username: config["USER"], password: config["PASS"]}
latest_keys = {}
prev_buid_failed = {}
response = ""
scheduler = Rufus::Scheduler.new
$bamboo_url = config["BAMBOO_URL"]
plan_keys = config["PLAN_KEYS"]

def broadcast(message)
  begin
    Telegram::Bot::Client.run($token) do |bot|
      bot.api.send_message(chat_id: $channel_id, text: message)
    end
  rescue Exception => e
    p "#{Time.now} Failed to send message!"
  end
end

scheduler.every '5s' do
  plan_keys.each do |plan|
    p plan
    response = HTTParty.get("#{$bamboo_url}/rest/api/latest/result/#{plan}.json?os_authType=basic", basic_auth: authinfo)
    latest_build_json = response.parsed_response.dig("results", "result").first
    latest_keys[plan] = latest_build_json["planResultKey"]["key"]

    if (latest_build_json["state"] != "Successful" && prev_buid_failed[plan] != true)
      indiv_response = HTTParty.get("#{$bamboo_url}/rest/api/latest/result/#{latest_keys[plan]}.json?os_authType=basic", basic_auth: authinfo)
      summary = Nokogiri::HTML(indiv_response.parsed_response["reasonSummary"])
      culprits = summary.css('a').map do |author|
        author.children.text
      end
      p "failed"
      broadcast("\xF0\x9F\x94\xA5[#{latest_build_json["plan"]["shortName"]}] build #{latest_keys[plan]} failed!\xF0\x9F\x94\xA5 \nCulprits: #{culprits}")
    elsif (latest_build_json["state"] == "Successful" && prev_buid_failed[plan] == true)
      p "passed"
      broadcast("\xF0\x9F\x8D\x80[]#{latest_build_json["plan"]["shortName"]}] build #{latest_keys[plan]} passing again!\xF0\x9F\x8D\x80")
    end

    if(latest_build_json["state"] == "Successful")
      prev_buid_failed[plan] = false
    else
      prev_buid_failed[plan] = true
    end
  end
end
scheduler.join
