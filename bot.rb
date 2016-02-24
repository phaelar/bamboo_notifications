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
frequency = config["FREQUENCY"]


def broadcast(message)
  backoff = 5
  loop do
    begin
      Telegram::Bot::Client.run($token) do |bot|
        bot.api.send_message(chat_id: $channel_id, text: message)
      end
      backoff = 0
    rescue Telegram::Bot::Exceptions::ResponseError => e
      p "#{Time.now} Failed to send message!"
      p e
      backoff = backoff * 5
    end
    break if backoff == 0
  end
end

def get_culprits(http_response)
  summary = Nokogiri::HTML(http_response.parsed_response["changes"])
end

scheduler.every frequency do
  plan_keys.each do |plan|
    p plan
    response = HTTParty.get("#{$bamboo_url}/rest/api/latest/result/#{plan}.json?os_authType=basic", basic_auth: authinfo)
    latest_build_json = response.parsed_response.dig("results", "result").first
    latest_keys[plan] = latest_build_json["planResultKey"]["key"]

    if (latest_build_json["state"] != "Successful" && prev_buid_failed[plan] != true)
      indiv_response = HTTParty.get("#{$bamboo_url}/rest/api/latest/result/#{latest_keys[plan]}.json?os_authType=basic&expand=changes.change", basic_auth: authinfo)
      culprits = indiv_response["changes"]["change"].map { |commit| commit["author"] unless commit["comment"].start_with?("Merge pull request") }.compact.uniq.join(', ')
      p "failed"
      url = "#{$bamboo_url}/browse/#{plan}/latest"
      broadcast("\xF0\x9F\x94\xA5[#{latest_build_json["plan"]["shortName"]}] build #{latest_keys[plan]} failed!\xF0\x9F\x94\xA5 \n#{url} \nCulprits: #{culprits}")
    elsif (latest_build_json["state"] == "Successful" && prev_buid_failed[plan] == true)
      p "passed"
      broadcast("\xF0\x9F\x8D\x80[#{latest_build_json["plan"]["shortName"]}] build #{latest_keys[plan]} passing again!\xF0\x9F\x8D\x80")
    end

    if(latest_build_json["state"] == "Successful")
      prev_buid_failed[plan] = false
    else
      prev_buid_failed[plan] = true
    end
  end
end
scheduler.join
