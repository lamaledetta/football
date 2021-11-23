import gspread
import pandas as pd
import time
import sys

from oauth2client.service_account import ServiceAccountCredentials

scope = ['https://spreadsheets.google.com/feeds',
         'https://www.googleapis.com/auth/drive']

credentials = ServiceAccountCredentials.from_json_keyfile_name("/Users/giacobba/git_repo/ev-rev/json/credentials.json", scope)

gc = gspread.authorize(credentials)

sh = gc.open("team_uu_rankings")

wks = sh.get_worksheet(0)
wks.clear()

if len(sys.argv)==1:
    filename = "~/Dropbox/My xG deliveries/pro-tableau/csv-factory/uu_teams_ita.csv"
else:
    filename = sys.argv[1]

# Google Sheets CSV separator
sep=';'

# Create empty dataframe
df = pd.DataFrame()
df = pd.read_csv(filename, sep=sep, header=None, index_col=False)

length=len(df.index)

my_list = df.values.tolist()

sh.values_update(
    'data!A1', 
    params={'valueInputOption': 'RAW'}, 
    body={'values': my_list}
)

