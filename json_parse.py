import json
import requests

query = requests.utils.quote(r'{"date_period":"all","emd_word":"","encodeURI":"true","expt_word":"","field":"","page":0,"query":"' + '문재인' + r'","siteid":"www","sort":"1","writer":""}')
data = requests.get(f'https://www.chosun.com/pf/api/v3/content/fetch/search-param-api?query={query}&d=301&_website=chosun').json()

print(data)