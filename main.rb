require "graphql/client"
require "graphql/client/http"
require "active_support"
require "active_support/all"
require "rest-client"
require "json"

# Star Wars API example wrapper
module SWAPI
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  HTTP = GraphQL::Client::HTTP.new("https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v2") do
    def headers(context)
      # Optionally set any HTTP headers
      { "User-Agent": "My Client" }
    end
  end  

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
  HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
    query($pairIn: [String!], $currentOlderTimestamp: BigInt, $fromTimestamp: BigInt) {
      swaps(first: 1000, where: {pair_in: $pairIn, timestamp_gt: $currentOlderTimestamp, timestamp_lt: $fromTimestamp}, orderBy: timestamp, orderDirection: desc) {
          pair {
            token0 {
              symbol
            __typename
          }
          token1 {
              symbol
            __typename
          }
          __typename
        }
        transaction {
            id
          __typename
        }
        timestamp
        sender
        amount0In
        amount1In
        amount0Out
        amount1Out
        amountUSD
        to
        __typename
      }
    }
  GRAPHQL
end
p 1
def message(swap)
  # total 购买/出售数量
  # amount 购买/出售价值
  message = "#{swap[:side] == '卖出' ? "📉" : "📈"}#{ENV['coin']} 当前 #{swap[:side]} #{swap[:total].to_d.round(2)} 个 #{ENV['coin']}, 平均价格 #{swap[:price].round(2)}(≈ $#{swap[:price_usd].round(2)})"
  RestClient.post("http://localhost:3000/send_message", {:name => "#{ENV['coin']}-Uniswap-交易提醒", :message => message}.to_json, headers={"Content-Type": "application/json"})

  swap
end

file_name = "#{ENV["pair"]}.config"


File.open(file_name, 'a+') do |file|
  @timestamp = file.read.to_i
  @timestamp = Time.now.to_i if @timestamp == 0
end

p @timestamp
while true do 
  result = SWAPI::Client.query(SWAPI::HeroNameQuery, variables: {
    "pairIn": [ENV["pair"]],
    "currentOlderTimestamp": @timestamp,
    "fromTimestamp": 1757605586
  }) rescue next
  result.data.to_h["swaps"]&.reverse&.each do |swap|
    if @timestamp < swap["timestamp"].to_i
      @timestamp = swap["timestamp"].to_i

      info = {}
      if swap["pair"]["token0"]["symbol"] == ENV["coin"]
        if swap["amount0In"] == "0"
          info[:side] ='买入'
          info[:total] = swap["amount0Out"]
          info[:amount] = swap["amount1In"]
          info[:buyer] = swap["from"]
        else
          info[:side] = '卖出'
          info[:amount] = swap["amount1Out"]
          info[:total] = swap["amount0In"]
          info[:buyer] = swap["to"]
        end
      else
        if swap["amount0In"] == "0"
          info[:side] = '卖出'
          info[:amount] = swap["amount0Out"]
          info[:total] = swap["amount1In"]
          info[:buyer] = swap["from"]
        else
          info[:side] = '买入'
          info[:total] = swap["amount1Out"]
          info[:amount] = swap["amount0In"]
          info[:buyer] = swap["to"]
        end
      end
      info[:amount_usd] = swap["amountUSD"]
      info[:price_usd] = info[:amount_usd].to_d / info[:total].to_d
      info[:price] = info[:amount].to_d / info[:total].to_d
      info[:coin0] = swap["pair"]["token0"]["symbol"]
      info[:coin1] = swap["pair"]["token1"]["symbol"]
      info[:tx_id] = swap["transaction"]["id"]
      info[:timestamp] = swap["timestamp"]
      File.open(file_name, "w") do |file|
        file.write @timestamp
      end
      # Todo 增加交易对判断，以稳定币或者某个币种位基准单位，可调整
      # Todo 多交易对一次查询
      # Todo 交易记录会丢失
      # 与微信机器人交互，格式化内容输出
      p message(info)
    end
  end
  sleep(1)
end
