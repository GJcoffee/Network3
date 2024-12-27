import os

import requests
import pymysql
from loguru import logger

host = os.getenv('host')
password = os.getenv('password')
mysql_config = {
    'host': host,
    'user': 'root',
    'port': 3306,
    'password': password,
    'database': 'airdrop',
    'cursorclass': pymysql.cursors.DictCursor
}

connect = pymysql.connect(**mysql_config)
cursor = connect.cursor()
cursor.execute("select * from network3 where status = 0")
data = list(cursor.fetchall())
cursor.close()
connect.close()

email_list = ['1909621145@qq.com', '9293678@qq.com', 'smithtoy387@gmail.com']
proxies = {'http': 'http://192.168.10.192:10809', 'https': 'http://192.168.10.192:10809'}
for task in data:
    try:
        headers = {
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Connection': 'keep-alive',
            'Origin': 'http://account.network3.ai:8080',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        }

        response = requests.post(f'http://{task.get("ip")}:18080/refresh', headers=headers, verify=False, proxies=proxies)
        logger.debug(response.text)
        k = response.json()['k']
        p = task['pubkey'].replace('System architecture is x86_64 (64-bit) ', '')
        headers = {
            'Accept': '*/*',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Origin': 'http://account.network3.ai:8080',
            'Pragma': 'no-cache',
            'Referer': 'http://account.network3.ai:8080/main2',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'X-Requested-With': 'XMLHttpRequest',
        }

        data = {
            'e': email_list[task.get('id') % 3],
            'k': k,
            'p': p,
        }

        response = requests.post(
            'http://account.network3.ai:8080/api/bind_email_node',
            headers=headers,
            data=data,
            verify=False,
            proxies=proxies
        )
        logger.debug(response.text)
        if response.json()['s'] == 0:
            connect = pymysql.connect(**mysql_config)
            cursor = connect.cursor()
            cursor.execute(f"update network3 set status = 1 where id={task.get('id')}")
            connect.commit()
            cursor.close()
            connect.close()
            logger.success(f"绑定成功 >>> {data}")

    except Exception as e:
        logger.error(e)
