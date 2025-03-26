# Periodic Update on Currency Exchange to RM and Tomei, continuesous listen request from Telegram and alert on Prices

import logging
import requests
from bs4 import BeautifulSoup
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes, CallbackContext
import asyncio
import datetime

# Replace with your bot's token
TOKEN = '7848695734:AAEUgu5FBlUr8UV2Ywnnc2wg9Ck14v6EZ5U'
CHAT_ID = '311196886'

# Set up logging
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    level=logging.INFO)
logger = logging.getLogger(__name__)

# Function to scrape Tomei gold price
def get_tomei_gold_price():
    # The URL of the live quotes API
    url = 'https://price-api.tomei.com.my/v1.0/price/gold-jewellery-and-silver-coin-prices/live-quotes-table'
    
    # Send GET request to the URL
    response = requests.get(url)

    if response.status_code == 200:
        # Parse the HTML content using BeautifulSoup
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find the table containing the gold prices
        table = soup.find('table', {'cellspacing': '0'})
        
        # Find the tbody and all tr elements
        table_body = soup.find('tbody')
        rows = table_body.find_all('tr')

        # Extract the 5th tr (index 4) and the 2nd td (index 1)
        fifth_row = rows[4]
        gold_prices = fifth_row.find_all('td')[1].text.strip()

        return gold_prices

# Function to send periodic updates
async def send_periodic_update(context: CallbackContext):
    # List of currencies to monitor
    currencies = ["THB", "JPY", "USD", "VND", "TWD"]

    # Get the Tomei gold price
    tomei_gold_price = get_tomei_gold_price()

    # Prepare the message with Tomei gold price
    message = f"Tomei Gold Price Update:\n9999 Wafer | Coin: {tomei_gold_price}\n\n"
    
    # Add currency exchange rates to the message
    for currency_code in currencies:
        try:
            best_buy, best_buy_location, best_sell, best_sell_location, unit = get_exchange_rate(currency_code)
            
            # Append the currency information to the message
            message += (f"Currency: {unit}\n"
                        f"Cheapest sell: {best_sell} at {best_sell_location}\n"
                        f"Highest buy: {best_buy} at {best_buy_location}\n\n")
        except Exception as e:
            message += f"Error during periodic check for {currency_code}: {str(e)}\n\n"
    
    # Send message to the user/chat
    await send_message(message)

# Function to send message
async def send_message(message: str):
    application = Application.builder().token(TOKEN).build()
    chat_id = CHAT_ID
    await application.bot.send_message(chat_id, message)

# Function to get exchange rates (existing functionality)
def get_exchange_rate(currency_code: str):
    url = f'https://www.klmoneychanger.com/compare-rates?n={currency_code}'
    response = requests.get(url)
    soup = BeautifulSoup(response.content, 'html.parser')

    rows = soup.find_all('tr')

    best_sell = float('inf')
    best_buy = float('-inf')
    best_sell_location = ""
    best_buy_location = ""

    for row in rows:
        cells = row.find_all('td')
        if len(cells) >= 4:
            location = cells[0].text.strip()
            unit = cells[1].text.strip()
            buy_price = cells[2].text.strip()
            sell_price = cells[3].text.strip()

            try:
                buy_value = float(buy_price)
                sell_value = float(sell_price)
                
                if buy_value > best_buy:
                    best_buy = buy_value
                    best_buy_location = location
                
                if sell_value < best_sell:
                    best_sell = sell_value
                    best_sell_location = location
            except ValueError:
                continue

    return best_buy, best_buy_location, best_sell, best_sell_location, unit

# Function to start the bot
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text('Hello! Send a currency code to get the exchange rates. Example: /currency JPY')
    await update.message.reply_text('Hello! To get Tomei Gold Bar Price. Example: /gold')

# Command handler function for exchange rates
async def get_currency(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if context.args:
        currency_code = context.args[0].upper()
        try:
            best_buy, best_buy_location, best_sell, best_sell_location, unit = get_exchange_rate(currency_code)

            # Prepare the message to send
            message = (f"{unit}\n\nCheapest sell is {best_sell} at {best_sell_location}.\n"
                       f"Highest buy is {best_buy} at {best_buy_location}.")
        except Exception as e:
            message = f"Error: {str(e)}"

    else:
        message = "Please provide a currency code. Example: /currency JPY"
    
    await update.message.reply_text(message)

# Command handler function for gold
async def get_gold_price(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        # Get the Tomei gold price
        tomei_gold_price = get_tomei_gold_price()

        # Prepare the message with Tomei gold price
        message = f"Tomei Gold Price :\n9999 Wafer | Coin: {tomei_gold_price}\n\n"

    except Exception as e:
        message = f"Error: {str(e)}"

    await update.message.reply_text(message)

# Main function to set up the bot
def main():
    # Create the Application and pass the bot token
    application = Application.builder().token(TOKEN).build()

    # Set up command handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("currency", get_currency))
    application.add_handler(CommandHandler("gold", get_gold_price))

    # Set up the JobQueue for periodic updates, but only between 10 AM and 10 PM
    job_queue = application.job_queue
    job_queue.run_repeating(
        lambda context: send_periodic_update(context) if 10 <= datetime.datetime.now().hour < 22 else None, 
        interval=1200, first=0  # 600 seconds = 10 minutes
    )

    # Run the bot
    application.run_polling()

if __name__ == '__main__':
    main()
