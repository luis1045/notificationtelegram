require "sinatra"
require "httparty"

# Escuchar en todas las interfaces (0.0.0.0) para red local
set :bind, '0.0.0.0'
set :port, 4567

# Configuración de tu bot
BOT_TOKEN = "8309997028:AAF18YU_h0Qs0RsbPa_VKvZcTvRI4XAYLR0"
CHAT_ID = "1936970256"
TELEGRAM_URL = "https://api.telegram.org/bot#{BOT_TOKEN}/sendMessage"


# Endpoint CoinGecko : solo permite 3 a 5 peticiones por segundo luego se bloquea
COINGECKO_URL = "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd"
#Endpoint de Binance : esto permite 1200 peticiones por segundo
BINANCE_URL = "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
# Variables globales para la alerta
$buy_price = nil
$profit_percent = nil
$drop_percent = nil
$target_profit = nil
$alert_stage = nil
$peak_price = nil

def send_telegram_message(text)
  HTTParty.post(TELEGRAM_URL, body: { chat_id: CHAT_ID, text: text })
end

#def get_btc_price
#  response = HTTParty.get(COINGECKO_URL)
#  response["bitcoin"]["usd"]
#end

def get_btc_price
  #resp = HTTParty.get(COINGECKO_URL)
  resp = HTTParty.get(BINANCE_URL)
  #puts"El Precio es :"+resp['bitcoin']['usd'].to_s
  puts"El Precio es :"+resp['price'].to_s
  if resp.code == 429
    puts "Demasiadas peticiones, esperando 20s..."
    #sleep(20)
    return get_btc_price
  elsif resp.success?
    #sleep(15)
    #return resp['bitcoin']['usd']
    return resp['price']
  else
    puts "Error #{resp.code}"
    return nil
  end
end

get "/price" do
  price = get_btc_price
  content_type :json
  { price: price }.to_json
end

Thread.new do
  loop do
    if $alert_stage
      current_price = get_btc_price
      puts "BTC: $#{current_price} | Stage: #{$alert_stage}"

      case $alert_stage
      when :profit
        if current_price >= $target_profit
          $peak_price = current_price
          send_telegram_message("🚀 BTC alcanzó tu meta de ganancia en $#{$target_profit}! Ahora monitoreando retroceso.")
          $alert_stage = :drop
        end
      when :drop
        drop_target = $peak_price * (1 - $drop_percent / 100)
        if current_price <= drop_target
          send_telegram_message("🔄 BTC retrocedió #{$drop_percent}% desde el máximo. Precio actual: $#{current_price}. Considera recomprar.")
          $alert_stage = nil
        end
      end
    end
    sleep 20
  end
end

get "/" do
  erb :index
end

# Endpoint AJAX para configurar alertas
post "/set_alert" do
  data = JSON.parse(request.body.read)
  $buy_price = data["buy_price"].to_f
  $profit_percent = data["profit_percent"].to_f
  $drop_percent = data["drop_percent"].to_f
  #variable para saber si esta en venta o en compra
  $type_operation = data["type_opetation"].to_s

  $target_profit = $buy_price * (1 + $profit_percent / 100)
  $alert_stage = :profit

  content_type :json
  { status: "ok", 
    target_profit: $target_profit.round(2), 
    drop_percent: $drop_percent,
    stage: $alert_stage 
  }.to_json
end

